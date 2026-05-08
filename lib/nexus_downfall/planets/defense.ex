defmodule NexusDownfall.Planets.Defense do
  @moduledoc "Stored quantity of one planetary defense type."

  use Ecto.Schema
  import Ecto.Changeset

  @defense_types [
    "missile_platform",
    "light_laser_tower",
    "heavy_laser_tower",
    "gauss_cannon",
    "ion_cannon",
    "plasma_turret",
    "planetary_shield_dome",
    "anti_siege_matrix",
    "orbital_interdiction_platform",
    "planetary_defense_bastion"
  ]

  def defense_types, do: @defense_types

  schema "planet_defenses" do
    field :defense_type, :string
    field :quantity, :integer, default: 0
    field :damaged_quantity, :integer, default: 0

    belongs_to :planet, NexusDownfall.Planets.Planet

    timestamps(type: :utc_datetime)
  end

  def changeset(defense, attrs) do
    defense
    |> cast(attrs, [:planet_id, :defense_type, :quantity, :damaged_quantity])
    |> validate_required([:planet_id, :defense_type, :quantity, :damaged_quantity])
    |> validate_inclusion(:defense_type, @defense_types)
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_number(:damaged_quantity, greater_than_or_equal_to: 0)
    |> unique_constraint([:planet_id, :defense_type])
  end
end
