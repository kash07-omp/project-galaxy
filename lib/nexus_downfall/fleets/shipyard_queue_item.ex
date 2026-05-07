defmodule NexusDownfall.Fleets.ShipyardQueueItem do
  @moduledoc "Queued ship construction request for a spaceport, targeted at a fleet."

  use Ecto.Schema
  import Ecto.Changeset

  @statuses ["queued", "building", "completed"]
  @ship_types [
    "light_freighter", "heavy_freighter",
    "light_fighter", "corvette", "missile_corvette",
    "heavy_fighter", "frigate", "light_destroyer", "bomber", "blocker", "colonizer",
    "cruiser", "carrier", "ew_cruiser", "battleship",
    "leviathan", "aphelion", "exodus"
  ]

  schema "shipyard_queue_items" do
    field :ship_type, :string
    field :quantity, :integer
    field :queue_position, :integer
    field :status, :string, default: "queued"
    field :build_seconds, :integer
    field :started_at, :utc_datetime
    field :finish_at, :utc_datetime
    field :oban_job_id, :integer

    belongs_to :planet, NexusDownfall.Planets.Planet
    belongs_to :fleet, NexusDownfall.Fleets.Fleet

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :planet_id,
      :fleet_id,
      :ship_type,
      :quantity,
      :queue_position,
      :status,
      :build_seconds,
      :started_at,
      :finish_at,
      :oban_job_id
    ])
    |> validate_required([
      :planet_id,
      :fleet_id,
      :ship_type,
      :quantity,
      :queue_position,
      :status,
      :build_seconds
    ])
    |> validate_inclusion(:ship_type, @ship_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:queue_position, greater_than: 0)
    |> validate_number(:build_seconds, greater_than: 0)
    |> unique_constraint([:planet_id, :queue_position])
  end
end
