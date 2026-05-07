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

  alias NexusDownfall.Planets.{Building, Planet, ProductionEngine}
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, SolarSystem}
  alias NexusDownfall.Workers.BuildCompleteWorker

  # ---------------------------------------------------------------------------
  # Phase 1 - basic CRUD
  # ---------------------------------------------------------------------------

  @doc "Creates the initial planet for a new `UniverseUser`, including starter buildings."
  def create_initial_planet(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> put_new_universe_id_from_solar_system()
      |> Map.put_new(:last_tick_at, now)

    with {:ok, planet} <- %Planet{} |> Planet.initial_changeset(attrs) |> Repo.insert() do
      {:ok, _} = ensure_building_slots(planet.id)
      set_starter_buildings(planet.id)

      {:ok, planet}
    end
  end

  @doc """
  Claims the first available planet slot in `solar_system_id` for a user.

  The selected slot is locked with `FOR UPDATE SKIP LOCKED`, making concurrent
  join attempts claim different slots instead of racing over the same row.
  Returns `{:error, :no_available_slots}` if all planet slots are taken.
  """
  def claim_planet_slot(solar_system_id, universe_user_id, name) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      planet =
        Repo.one(
          from p in Planet,
            where:
              p.solar_system_id == ^solar_system_id and
                p.slot_type == "planet" and
                is_nil(p.universe_user_id),
            order_by: p.orbit_position,
            limit: 1,
            lock: "FOR UPDATE SKIP LOCKED"
        )

      if is_nil(planet), do: Repo.rollback(:no_available_slots)

      updated_planet =
        planet
        |> Ecto.Changeset.change(%{
          name: name,
          universe_user_id: universe_user_id,
          last_tick_at: now
        })
        |> Repo.update!()

      {:ok, _} = ensure_building_slots(updated_planet.id)
      set_starter_buildings(updated_planet.id)

      updated_planet
    end)
    |> case do
      {:ok, planet} -> {:ok, planet}
      {:error, reason} -> {:error, reason}
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

  @doc "Gets a planet owned by `user_id`, with buildings preloaded. Raises if not found."
  def get_user_planet!(planet_id, user_id) do
    Repo.one!(
      from p in Planet,
        join: uu in assoc(p, :universe_user),
        where: p.id == ^planet_id and uu.user_id == ^user_id,
        preload: [:buildings]
    )
  end

  # ---------------------------------------------------------------------------
  # Phase 2 - buildings
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
  - `{:error, :planet_busy}` if another building is already in progress.
  - `{:error, :insufficient_resources}` if the planet cannot afford the upgrade.
  - `{:error, changeset}` on DB error.
  """
  def start_construction(planet_id, building_type) do
    Repo.transaction(fn ->
      planet = lock_planet!(planet_id)
      start_construction_for_locked_planet(planet, building_type)
    end)
    |> emit_construction_started()
  end

  @doc """
  Starts construction only if `planet_id` belongs to `user_id`.

  Returns `{:error, :not_found}` for missing or unauthorized planets to avoid
  leaking ownership information.
  """
  def start_construction_for_user(planet_id, user_id, building_type) do
    Repo.transaction(fn ->
      planet =
        Repo.one(
          from p in Planet,
            join: uu in assoc(p, :universe_user),
            where: p.id == ^planet_id and uu.user_id == ^user_id,
            lock: "FOR UPDATE"
        )

      if is_nil(planet), do: Repo.rollback(:not_found)

      start_construction_for_locked_planet(planet, building_type)
    end)
    |> emit_construction_started()
    |> emit_unauthorized_construction_attempt(planet_id, user_id)
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
    |> case do
      {:ok, updated_planet} = result ->
        emit_production_applied(updated_planet.id)
        result

      error ->
        error
    end
  end

  defp start_construction_for_locked_planet(%Planet{} = planet, building_type) do
    {:ok, _} = ensure_building_slots(planet.id)

    buildings = list_buildings_for_update(planet.id)
    planet = persist_production_tick!(planet, buildings)

    building =
      Enum.find(buildings, fn b -> b.type == building_type end) ||
        %Building{type: building_type, planet_id: planet.id, level: 0}

    if building.construction_finish_at != nil do
      Repo.rollback(:already_constructing)
    end

    any_constructing = Enum.any?(buildings, fn b -> b.construction_finish_at != nil end)
    if any_constructing, do: Repo.rollback(:planet_busy)

    next_level = building.level + 1
    cost = ProductionEngine.build_cost(building_type, next_level)

    unless ProductionEngine.can_afford?(planet, cost) do
      Repo.rollback(:insufficient_resources)
    end

    deductions = ProductionEngine.deduct_cost(planet, cost)

    planet
    |> Ecto.Changeset.cast(deductions, Map.keys(deductions))
    |> Repo.update!()

    build_secs = ProductionEngine.build_time_seconds(building_type, next_level)

    finish_at =
      DateTime.add(DateTime.utc_now(), build_secs, :second) |> DateTime.truncate(:second)

    saved_building =
      case building do
        %Building{id: nil} ->
          %Building{}
          |> Building.changeset(%{type: building_type, planet_id: planet.id, level: 0})
          |> Repo.insert!()

        existing ->
          existing
      end

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

    Repo.update_all(
      from(b in Building,
        where: b.id == ^saved_building.id and not is_nil(b.construction_finish_at)
      ),
      set: [oban_job_id: job.id]
    )

    saved_building
  end

  defp set_starter_buildings(planet_id) do
    Repo.update_all(
      from(b in Building,
        where: b.planet_id == ^planet_id and b.type in ^["command_center", "power_plant"]
      ),
      set: [level: 1]
    )
  end

  defp list_buildings_for_update(planet_id) do
    Repo.all(
      from b in Building,
        where: b.planet_id == ^planet_id,
        order_by: b.type,
        lock: "FOR UPDATE"
    )
  end

  defp lock_planet!(planet_id) do
    Repo.one!(from p in Planet, where: p.id == ^planet_id, lock: "FOR UPDATE")
  end

  defp persist_production_tick!(planet, buildings) do
    attrs = ProductionEngine.apply_tick(planet, buildings)

    planet
    |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
    |> Repo.update!()
    |> tap(fn updated_planet -> emit_production_applied(updated_planet.id) end)
  end

  defp put_new_universe_id_from_solar_system(attrs) do
    has_universe_id? = Map.has_key?(attrs, :universe_id) or Map.has_key?(attrs, "universe_id")
    solar_system_id = Map.get(attrs, :solar_system_id) || Map.get(attrs, "solar_system_id")

    if has_universe_id? or is_nil(solar_system_id) do
      attrs
    else
      Map.put(attrs, :universe_id, universe_id_for_solar_system(solar_system_id))
    end
  end

  defp universe_id_for_solar_system(solar_system_id) do
    Repo.one!(
      from s in SolarSystem,
        join: g in Galaxy,
        on: g.id == s.galaxy_id,
        where: s.id == ^solar_system_id,
        select: g.universe_id
    )
  end

  defp emit_construction_started({:ok, %Building{} = building} = result) do
    :telemetry.execute(
      [:nexus_downfall, :planets, :construction_started],
      %{count: 1},
      %{planet_id: building.planet_id, building_type: building.type}
    )

    result
  end

  defp emit_construction_started(result), do: result

  defp emit_unauthorized_construction_attempt({:error, :not_found} = result, planet_id, user_id) do
    :telemetry.execute(
      [:nexus_downfall, :planets, :unauthorized_access],
      %{count: 1},
      %{planet_id: planet_id, user_id: user_id, action: :start_construction}
    )

    result
  end

  defp emit_unauthorized_construction_attempt(result, _planet_id, _user_id), do: result

  defp emit_production_applied(planet_id) do
    :telemetry.execute(
      [:nexus_downfall, :planets, :production_applied],
      %{count: 1},
      %{planet_id: planet_id}
    )
  end
end
