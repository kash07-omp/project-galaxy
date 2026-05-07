defmodule NexusDownfall.Planets do
  @moduledoc """
  Planets context.

  Manages planetary micro-management: buildings, resource production,
  energy balance, population, construction queues, and governors.

  ## Phase roadmap
  - Phase 0: Module stub (structure only).
  - Phase 1: Initial planet creation on universe join.
  - Phase 2: Buildings, production engine, energy rules, construction queue (Oban).
  """

  import Ecto.Query
  alias NexusDownfall.Repo
  alias NexusDownfall.Planets.{Planet, Building, ProductionEngine}
  alias NexusDownfall.Workers.BuildCompleteWorker

  # ---------------------------------------------------------------------------
  # Phase 1 — basic CRUD
  # ---------------------------------------------------------------------------

  @doc "Creates the initial planet for a new `UniverseUser`, including starter buildings."
  def create_initial_planet(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = Map.put_new(attrs, :last_tick_at, now)

    with {:ok, planet} <- %Planet{} |> Planet.initial_changeset(attrs) |> Repo.insert() do
      {:ok, _} = ensure_building_slots(planet.id)

      # Pre-build command_center + power_plant at level 1 (starter infrastructure).
      # This gives the planet energy immediately so mines/farms can produce from day 1.
      Repo.update_all(
        from(b in Building,
          where: b.planet_id == ^planet.id and b.type in ^["command_center", "power_plant"]),
        set: [level: 1]
      )

      {:ok, planet}
    end
  end

  @doc """
  Claims the first available (unoccupied) planet slot in `solar_system_id` for a user.

  Finds a pre-seeded slot with `slot_type: "planet"` and `universe_user_id: nil`,
  assigns the user, creates building slots, and pre-builds starter infrastructure.
  Returns `{:error, :no_available_slots}` if all slots are taken.
  """
  def claim_planet_slot(solar_system_id, universe_user_id, name) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.one(
           from p in Planet,
             where:
               p.solar_system_id == ^solar_system_id and
                 p.slot_type == "planet" and
                 is_nil(p.universe_user_id),
             order_by: p.orbit_position,
             limit: 1
         ) do
      nil ->
        {:error, :no_available_slots}

      planet ->
        planet
        |> Ecto.Changeset.change(%{
          name: name,
          universe_user_id: universe_user_id,
          last_tick_at: now
        })
        |> Repo.update()
        |> case do
          {:ok, updated_planet} ->
            {:ok, _} = ensure_building_slots(updated_planet.id)

            Repo.update_all(
              from(b in Building,
                where:
                  b.planet_id == ^updated_planet.id and
                    b.type in ^["command_center", "power_plant"]),
              set: [level: 1]
            )

            {:ok, updated_planet}

          error ->
            error
        end
    end
  end

  @doc "Returns all planets belonging to `universe_user_id`, with buildings preloaded."
  def list_planets_for_user(universe_user_id) do
    Repo.all(
      from p in Planet,
        where: p.universe_user_id == ^universe_user_id,
        preload: [:buildings]
    )
  end

  @doc "Gets a planet with buildings preloaded. Raises if not found."
  def get_planet!(id) do
    Planet
    |> Repo.get!(id)
    |> Repo.preload(:buildings)
  end

  # ---------------------------------------------------------------------------
  # Phase 2 — buildings
  # ---------------------------------------------------------------------------

  @doc "Returns the list of buildings for `planet_id`, ordered by type."
  def list_buildings(planet_id) do
    Repo.all(from b in Building, where: b.planet_id == ^planet_id, order_by: b.type)
  end

  @doc """
  Ensures all canonical building types exist for `planet_id`, inserting them
  at level 0 if they are missing. Returns {:ok, buildings_list} | {:error, reason}.
  Called once per planet on first view.
  """
  def ensure_building_slots(planet_id) do
    existing_types =
      Repo.all(from b in Building, where: b.planet_id == ^planet_id, select: b.type)

    missing = Building.building_types() -- existing_types

    results =
      Enum.map(missing, fn type ->
        %Building{}
        |> Building.changeset(%{type: type, planet_id: planet_id, level: 0})
        |> Repo.insert(on_conflict: :nothing)
      end)

    errors = Enum.filter(results, fn {tag, _} -> tag == :error end)

    if errors == [] do
      {:ok, list_buildings(planet_id)}
    else
      {:error, errors}
    end
  end

  @doc """
  Starts construction/upgrade of a building.

  ## Returns
  - `{:ok, building}` on success.
  - `{:error, :already_constructing}` if the building is already in progress.
  - `{:error, :insufficient_resources}` if the planet cannot afford the upgrade.
  - `{:error, changeset}` on DB error.
  """
  def start_construction(planet_id, building_type) do
    Repo.transaction(fn ->
      planet = Repo.get!(Planet, planet_id)
      buildings = list_buildings(planet_id)

      building =
        Enum.find(buildings, fn b -> b.type == building_type end) ||
          %Building{type: building_type, planet_id: planet_id, level: 0}

      if building.construction_finish_at != nil do
        Repo.rollback(:already_constructing)
      end

      # Planet-wide lock: only one building can be under construction at a time
      any_constructing = Enum.any?(buildings, fn b -> b.construction_finish_at != nil end)
      if any_constructing, do: Repo.rollback(:planet_busy)

      next_level = building.level + 1
      cost = ProductionEngine.build_cost(building_type, next_level)

      unless ProductionEngine.can_afford?(planet, cost) do
        Repo.rollback(:insufficient_resources)
      end

      # Deduct resources
      deductions = ProductionEngine.deduct_cost(planet, cost)

      planet
      |> Ecto.Changeset.cast(deductions, Map.keys(deductions))
      |> Repo.update!()

      # Schedule Oban job
      build_secs = ProductionEngine.build_time_seconds(building_type, next_level)
      finish_at = DateTime.add(DateTime.utc_now(), build_secs, :second) |> DateTime.truncate(:second)

      # Upsert building record and capture id
      saved_building =
        case building do
          %Building{id: nil} ->
            %Building{}
            |> Building.changeset(%{type: building_type, planet_id: planet_id, level: 0})
            |> Repo.insert!()

          existing ->
            existing
        end

      # Mark building as under construction BEFORE inserting the Oban job
      # so that inline test mode (which runs the job synchronously) sees the
      # correct state when BuildCompleteWorker reads the building.
      saved_building =
        saved_building
        |> Building.changeset(%{construction_finish_at: finish_at})
        |> Repo.update!()

      {:ok, job} =
        BuildCompleteWorker.new(
          %{"building_id" => saved_building.id},
          scheduled_at: finish_at
        )
        |> Oban.insert()

      # Store the job reference as a best-effort update; if the job already ran
      # inline (test env) the building may already be at the next level — that
      # is fine, we just skip re-marking it.
      Repo.update_all(
        Ecto.Query.from(b in Building,
          where: b.id == ^saved_building.id and not is_nil(b.construction_finish_at)
        ),
        set: [oban_job_id: job.id]
      )

      saved_building
    end)
  end

  @doc """
  Applies accumulated resource production since `planet.last_tick_at` and
  persists the result. Returns `{:ok, updated_planet}`.
  """
  def apply_production_tick(planet) do
    buildings = list_buildings(planet.id)
    attrs = ProductionEngine.apply_tick(planet, buildings)

    planet
    |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
    |> Repo.update()
  end
end
