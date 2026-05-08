defmodule NexusDownfall.Planets.DefenseQueueItem do
  @moduledoc "Queued planetary defense construction request for a defense center."

  use Ecto.Schema
  import Ecto.Changeset

  alias NexusDownfall.Planets.Defense

  @statuses ["queued", "building", "completed"]

  schema "defense_queue_items" do
    field :defense_type, :string
    field :quantity, :integer
    field :queue_position, :integer
    field :status, :string, default: "queued"
    field :build_seconds, :integer
    field :started_at, :utc_datetime
    field :finish_at, :utc_datetime
    field :oban_job_id, :integer

    belongs_to :planet, NexusDownfall.Planets.Planet

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :planet_id,
      :defense_type,
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
      :defense_type,
      :quantity,
      :queue_position,
      :status,
      :build_seconds
    ])
    |> validate_inclusion(:defense_type, Defense.defense_types())
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:queue_position, greater_than: 0)
    |> validate_number(:build_seconds, greater_than: 0)
    |> unique_constraint([:planet_id, :queue_position])
  end
end
