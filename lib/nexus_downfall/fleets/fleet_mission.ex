defmodule NexusDownfall.Fleets.FleetMission do
  @moduledoc "Mission lifecycle record for fleets."

  use Ecto.Schema
  import Ecto.Changeset

  @mission_types ["colonization", "transport", "attack"]
  @active_phases ["outbound", "colonizing", "returning"]
  @terminal_phases ["completed", "failed"]
  @phases @active_phases ++ @terminal_phases

  schema "fleet_missions" do
    field :mission_type, :string
    field :phase, :string, default: "outbound"
    field :result_reason, :string

    field :route_system_ids, {:array, :integer}, default: []

    field :outbound_travel_seconds, :integer
    field :colonization_seconds, :integer
    field :return_travel_seconds, :integer

    field :hydrogen_cost, :integer
    field :cargo_raw_materials, :integer, default: 0
    field :cargo_microchips, :integer, default: 0
    field :cargo_hydrogen, :integer, default: 0
    field :cargo_food, :integer, default: 0
    field :cargo_credits, :integer, default: 0

    field :outbound_arrival_at, :utc_datetime
    field :colonization_complete_at, :utc_datetime
    field :return_arrival_at, :utc_datetime
    field :completed_at, :utc_datetime

    field :current_oban_job_id, :integer

    belongs_to :fleet, NexusDownfall.Fleets.Fleet
    belongs_to :origin_planet, NexusDownfall.Planets.Planet
    belongs_to :target_planet, NexusDownfall.Planets.Planet
    belongs_to :universe_user, NexusDownfall.Accounts.UniverseUser
    belongs_to :universe, NexusDownfall.Universe.UniverseRecord

    timestamps(type: :utc_datetime)
  end

  def changeset(mission, attrs) do
    mission
    |> cast(attrs, [
      :mission_type,
      :phase,
      :result_reason,
      :route_system_ids,
      :outbound_travel_seconds,
      :colonization_seconds,
      :return_travel_seconds,
      :hydrogen_cost,
      :cargo_raw_materials,
      :cargo_microchips,
      :cargo_hydrogen,
      :cargo_food,
      :cargo_credits,
      :outbound_arrival_at,
      :colonization_complete_at,
      :return_arrival_at,
      :completed_at,
      :current_oban_job_id,
      :fleet_id,
      :origin_planet_id,
      :target_planet_id,
      :universe_user_id,
      :universe_id
    ])
    |> validate_required([
      :mission_type,
      :phase,
      :route_system_ids,
      :outbound_travel_seconds,
      :colonization_seconds,
      :return_travel_seconds,
      :hydrogen_cost,
      :cargo_raw_materials,
      :cargo_microchips,
      :cargo_hydrogen,
      :cargo_food,
      :cargo_credits,
      :outbound_arrival_at,
      :fleet_id,
      :origin_planet_id,
      :target_planet_id,
      :universe_user_id,
      :universe_id
    ])
    |> validate_inclusion(:mission_type, @mission_types)
    |> validate_inclusion(:phase, @phases)
    |> validate_number(:outbound_travel_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:colonization_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:return_travel_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:hydrogen_cost, greater_than_or_equal_to: 0)
    |> validate_number(:cargo_raw_materials, greater_than_or_equal_to: 0)
    |> validate_number(:cargo_microchips, greater_than_or_equal_to: 0)
    |> validate_number(:cargo_hydrogen, greater_than_or_equal_to: 0)
    |> validate_number(:cargo_food, greater_than_or_equal_to: 0)
    |> validate_number(:cargo_credits, greater_than_or_equal_to: 0)
    |> unique_constraint(:fleet_id, name: :fleet_missions_one_active_per_fleet_idx)
  end

  def active_phases, do: @active_phases
  def terminal_phases, do: @terminal_phases
end
