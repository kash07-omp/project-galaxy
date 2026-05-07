defmodule NexusDownfall.Cards.UserCard do
  @moduledoc "Tracks which cards a universe_user owns in their deck."

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_cards" do
    belongs_to :universe_user, NexusDownfall.Accounts.UniverseUser
    belongs_to :card, NexusDownfall.Cards.Card

    timestamps(type: :utc_datetime)
  end

  def changeset(user_card, attrs) do
    user_card
    |> cast(attrs, [:universe_user_id, :card_id])
    |> validate_required([:universe_user_id, :card_id])
    |> foreign_key_constraint(:universe_user_id)
    |> foreign_key_constraint(:card_id)
    |> unique_constraint([:universe_user_id, :card_id])
  end
end
