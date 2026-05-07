defmodule NexusDownfall.Universe do
  @moduledoc """
  Universe context.

  Manages the macro-structure of the game world: universes (servers),
  galaxies, solar systems, hyperlinks between systems and star system slots.

  Telemetry events:
  - `[:nexus_downfall, :universe, :created]`

  ## Phase roadmap
  - Phase 0: Module stub (structure only).
  - Phase 1: Universe schema + basic CRUD (list open universes, create).
  - Phase 3: Galaxy/system generation, A* pathfinding for fleet routes, hyperlinks.
  """

  import Ecto.Query

  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, Hyperlink, SolarSystem}
  alias NexusDownfall.Universe.UniverseRecord, as: UniverseSchema

  @doc "Lists all universes with `status: open`."
  def list_open_universes do
    Repo.all(from u in UniverseSchema, where: u.status == "open", order_by: [asc: u.inserted_at])
  end

  @doc "Gets a universe by slug."
  def get_universe_by_slug(slug) when is_binary(slug) do
    Repo.get_by(UniverseSchema, slug: slug)
  end

  @doc "Gets a universe by id. Raises if not found."
  def get_universe!(id), do: Repo.get!(UniverseSchema, id)

  @doc "Finds the id of the first available solar system in a universe. Returns nil if none."
  def find_available_solar_system(%UniverseSchema{id: universe_id}) do
    query =
      from s in SolarSystem,
        join: g in Galaxy,
        on: g.id == s.galaxy_id,
        join: p in assoc(s, :planets),
        where: g.universe_id == ^universe_id,
        where: p.slot_type == "planet" and is_nil(p.universe_user_id),
        order_by: [asc: g.number, asc: s.number],
        limit: 1,
        select: s.id

    Repo.one(query)
  end

  @doc "Gets a galaxy with all its solar systems and their planets."
  def get_galaxy_with_systems!(galaxy_id) do
    Repo.one!(
      from g in Galaxy,
        where: g.id == ^galaxy_id,
        preload: [solar_systems: [planets: [:universe_user]]]
    )
  end

  @doc """
  Returns all hyperlinks in a galaxy (both directions), with systems preloaded.
  Each hyperlink has :system_a and :system_b preloaded.
  """
  def list_hyperlinks_for_galaxy(galaxy_id) do
    system_ids =
      from(s in SolarSystem, where: s.galaxy_id == ^galaxy_id, select: s.id)

    Repo.all(
      from h in Hyperlink,
        where: h.system_a_id in subquery(system_ids),
        preload: [:system_a, :system_b]
    )
  end

  @doc """
  Gets a solar system with its planets preloaded (including universe_user and user).
  """
  def get_system_with_planets!(system_id) do
    Repo.one!(
      from s in SolarSystem,
        where: s.id == ^system_id,
        preload: [
          galaxy: [],
          planets: [universe_user: [:user]]
        ]
    )
  end

  @doc "Creates a hyperlink between two solar systems."
  def create_hyperlink(system_a_id, system_b_id) do
    {a, b} =
      if system_a_id < system_b_id,
        do: {system_a_id, system_b_id},
        else: {system_b_id, system_a_id}

    %Hyperlink{}
    |> Hyperlink.changeset(%{system_a_id: a, system_b_id: b})
    |> Repo.insert()
  end

  @doc "Creates a universe."
  def create_universe(attrs) do
    result = %UniverseSchema{} |> UniverseSchema.creation_changeset(attrs) |> Repo.insert()

    case result do
      {:ok, universe} ->
        :telemetry.execute(
          [:nexus_downfall, :universe, :created],
          %{count: 1},
          %{universe_id: universe.id}
        )

        {:ok, universe}

      error ->
        error
    end
  end
end
