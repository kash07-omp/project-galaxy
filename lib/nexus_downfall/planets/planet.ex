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
    field :slot_type, :string, default: "planet"
    field :planet_subtype, :string
    field :raw_materials, :integer, default: 500
    field :planet_image_id, :integer, default: 1
    field :microchips, :integer, default: 500
    field :hydrogen, :integer, default: 500
    field :food, :integer, default: 500
    field :credits, :integer, default: 1000
    field :population, :integer, default: 100
    field :last_tick_at, :utc_datetime

    belongs_to :universe, NexusDownfall.Universe.UniverseRecord, foreign_key: :universe_id
    belongs_to :solar_system, NexusDownfall.Universe.SolarSystem
    belongs_to :universe_user, NexusDownfall.Accounts.UniverseUser
    has_many :buildings, NexusDownfall.Planets.Building
    has_many :defenses, NexusDownfall.Planets.Defense
    has_many :defense_queue_items, NexusDownfall.Planets.DefenseQueueItem
    has_many :home_fleets, NexusDownfall.Fleets.Fleet, foreign_key: :home_planet_id
    has_many :shipyard_queue_items, NexusDownfall.Fleets.ShipyardQueueItem

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for the initial planet created when joining a universe."
  def initial_changeset(planet, attrs) do
    planet
    |> cast(attrs, [
      :name,
      :orbit_position,
      :region,
      :slot_type,
      :planet_subtype,
      :universe_id,
      :solar_system_id,
      :universe_user_id,
      :last_tick_at
    ])
    |> validate_required([:orbit_position, :region, :slot_type, :universe_id, :solar_system_id])
    |> validate_inclusion(:slot_type, ["planet", "asteroid_ring"])
    |> validate_inclusion(
      :planet_subtype,
      ["rocky", "gas_giant", "ice", "ocean", "lava", "desert"],
      allow_nil: true
    )
    |> validate_length(:name, min: 2, max: 50, allow_nil: true)
    |> validate_number(:orbit_position, greater_than: 0, less_than_or_equal_to: 15)
    |> validate_number(:region, greater_than: 0, less_than_or_equal_to: 3)
    |> unique_constraint([:solar_system_id, :orbit_position, :region])
  end
end
