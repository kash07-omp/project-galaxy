defmodule NexusDownfall.Planets.Building do
  @moduledoc """
  A building slot on a planet.

  Each planet can have one row per building type (unique constraint).
  `level: 0` means the building does not yet exist and must be constructed.
  When `construction_finish_at` is set, an upgrade to `level + 1` is in progress.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @building_types ~w(
    command_center
    mine_raw
    microchip_factory
    hydrogen_extractor
    farm
    power_plant
    nuclear_reactor
    residential
    laboratory
    spaceport
    defense_center
    component_factory
  )

  def building_types, do: @building_types

  schema "buildings" do
    field :type, :string
    field :level, :integer, default: 0
    field :construction_finish_at, :utc_datetime
    field :oban_job_id, :integer

    belongs_to :planet, NexusDownfall.Planets.Planet

    timestamps(type: :utc_datetime)
  end

  def changeset(building, attrs) do
    building
    |> cast(attrs, [:type, :level, :planet_id, :construction_finish_at, :oban_job_id])
    |> validate_required([:type, :planet_id])
    |> validate_inclusion(:type, @building_types)
    |> validate_number(:level, greater_than_or_equal_to: 0)
    |> unique_constraint([:planet_id, :type])
  end
end
