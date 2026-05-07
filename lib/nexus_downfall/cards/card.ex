defmodule NexusDownfall.Cards.Card do
  @moduledoc """
  A collectible card. Cards are globally defined (by admins/seed) and players
  obtain copies into their per-universe deck.

  ## Card types
  - `"admiral"` — grants fleet bonuses when assigned to a fleet.
  (future: `"ship"`, `"equipment"`, `"technology"`, ...)

  ## Bonuses format (stored as JSONB map)
      %{
        "effects" => [
          %{
            "type"       => "stat_bonus",
            "stat"       => "evasion",          # semantic stat name
            "ship_types" => ["light_fighter"],   # which ships are affected, [] = all
            "modifier"   => "percentage",        # "percentage" | "flat"
            "value"      => 5                    # numeric amount
          }
        ]
      }
  """

  use Ecto.Schema
  import Ecto.Changeset

  @card_types ~w(admiral)
  @rarities ~w(common rare epic legendary)

  schema "cards" do
    field :type, :string
    field :slug, :string
    field :name, :string
    field :description, :string
    field :image_path, :string
    field :rarity, :string, default: "common"
    field :bonuses, :map, default: %{}

    has_many :user_cards, NexusDownfall.Cards.UserCard

    timestamps(type: :utc_datetime)
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:type, :slug, :name, :description, :image_path, :rarity, :bonuses])
    |> validate_required([:type, :slug, :name])
    |> validate_inclusion(:type, @card_types)
    |> validate_inclusion(:rarity, @rarities)
    |> unique_constraint(:slug)
  end
end
