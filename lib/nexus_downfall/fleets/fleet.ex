defmodule NexusDownfall.Fleets.Fleet do
  @moduledoc "Player fleet with optional admiral assignment and ship composition."

  use Ecto.Schema
  import Ecto.Changeset

  schema "fleets" do
    field :name, :string
    field :admiral_name, :string
    field :status, :string, default: "idle"

    belongs_to :universe, NexusDownfall.Universe.UniverseRecord
    belongs_to :universe_user, NexusDownfall.Accounts.UniverseUser
    belongs_to :home_planet, NexusDownfall.Planets.Planet
    belongs_to :admiral_card, NexusDownfall.Cards.Card
    has_many :ships, NexusDownfall.Fleets.FleetShip
    has_many :shipyard_queue_items, NexusDownfall.Fleets.ShipyardQueueItem

    timestamps(type: :utc_datetime)
  end

  def changeset(fleet, attrs) do
    fleet
    |> cast(attrs, [:name, :admiral_name, :status, :universe_id, :universe_user_id, :home_planet_id, :admiral_card_id])
    |> validate_required([:name, :status, :universe_id, :universe_user_id, :home_planet_id])
    |> validate_length(:name, min: 2, max: 40)
    |> validate_length(:admiral_name, max: 60)
    |> validate_inclusion(:status, ["idle"])
    |> unique_constraint([:universe_user_id, :name])
    |> unique_constraint(:admiral_card_id,
      name: :fleets_universe_user_id_admiral_card_id_unique_idx,
      message: "card_already_assigned"
    )
  end
end
