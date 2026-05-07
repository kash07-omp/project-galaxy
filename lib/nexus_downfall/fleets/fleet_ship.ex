defmodule NexusDownfall.Fleets.FleetShip do
  @moduledoc "Stored quantity of a ship type assigned to a fleet."

  use Ecto.Schema
  import Ecto.Changeset

  @ship_types [
    "light_freighter", "heavy_freighter",
    "light_fighter", "corvette", "missile_corvette",
    "heavy_fighter", "frigate", "light_destroyer", "bomber", "blocker", "colonizer",
    "cruiser", "carrier", "ew_cruiser", "battleship",
    "leviathan", "aphelion", "exodus"
  ]

  def ship_types, do: @ship_types

  schema "fleet_ships" do
    field :ship_type, :string
    field :quantity, :integer, default: 0

    belongs_to :fleet, NexusDownfall.Fleets.Fleet

    timestamps(type: :utc_datetime)
  end

  def changeset(fleet_ship, attrs) do
    fleet_ship
    |> cast(attrs, [:fleet_id, :ship_type, :quantity])
    |> validate_required([:fleet_id, :ship_type, :quantity])
    |> validate_inclusion(:ship_type, @ship_types)
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> unique_constraint([:fleet_id, :ship_type])
  end
end
