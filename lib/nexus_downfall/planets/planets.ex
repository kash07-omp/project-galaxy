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

  alias NexusDownfall.Repo
  alias NexusDownfall.Planets.Planet

  @doc "Creates the initial planet for a new `UniverseUser`."
  def create_initial_planet(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = Map.put_new(attrs, :last_tick_at, now)

    %Planet{} |> Planet.initial_changeset(attrs) |> Repo.insert()
  end

  @doc "Returns all planets belonging to `universe_user_id`."
  def list_planets_for_user(universe_user_id) do
    import Ecto.Query
    Repo.all(from p in Planet, where: p.universe_user_id == ^universe_user_id)
  end

  @doc "Gets a planet. Raises if not found."
  def get_planet!(id), do: Repo.get!(Planet, id)
end
