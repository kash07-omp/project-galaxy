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
  alias NexusDownfall.Universe.{Galaxy, SolarSystem}
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
        where: g.universe_id == ^universe_id,
        order_by: [asc: g.number, asc: s.number],
        limit: 1,
        select: s.id

    Repo.one(query)
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
