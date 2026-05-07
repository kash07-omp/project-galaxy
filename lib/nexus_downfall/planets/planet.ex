defmodule NexusDownfall.Planets.Planet do
  @moduledoc """
  Ecto schema for the `planets` table.

  Resources (`raw_materials`, `microchips`, `hydrogen`, `food`, `credits`)
  accumulate continuously. The `last_tick_at` field marks the last time the
  resource engine resolved offline accumulation for this planet.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "planets" do
    field :name, :string
    field :orbit_position, :integer
    field :region, :integer, default: 1
    field :raw_materials, :float, default: 500.0
    field :microchips, :float, default: 500.0
    field :hydrogen, :float, default: 500.0
    field :food, :float, default: 500.0
    field :credits, :float, default: 1000.0
    field :population, :integer, default: 100
    field :last_tick_at, :utc_datetime

    belongs_to :solar_system, NexusDownfall.Universe.SolarSystem
    belongs_to :universe_user, NexusDownfall.Accounts.UniverseUser
    has_many :buildings, NexusDownfall.Planets.Building

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for the initial planet created when joining a universe."
  def initial_changeset(planet, attrs) do
    planet
    |> cast(attrs, [
      :name,
      :orbit_position,
      :region,
      :solar_system_id,
      :universe_user_id,
      :last_tick_at
    ])
    |> validate_required([:name, :orbit_position, :region, :solar_system_id, :last_tick_at])
    |> validate_length(:name, min: 2, max: 50)
    |> validate_number(:orbit_position, greater_than: 0, less_than_or_equal_to: 15)
    |> validate_number(:region, greater_than: 0, less_than_or_equal_to: 3)
    |> unique_constraint([:solar_system_id, :orbit_position, :region])
  end
end
