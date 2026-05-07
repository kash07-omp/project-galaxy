defmodule NexusDownfall.Cards do
  @moduledoc """
  Cards context.

  Manages the global card catalog and per-universe-user card ownership (deck).
  """

  import Ecto.Query

  alias NexusDownfall.Cards.{Card, UserCard}
  alias NexusDownfall.Repo
  alias NexusDownfall.Accounts.UniverseUser

  # ---------------------------------------------------------------------------
  # Catalog
  # ---------------------------------------------------------------------------

  def get_card!(id), do: Repo.get!(Card, id)

  def get_card_by_slug(slug), do: Repo.get_by(Card, slug: slug)

  # ---------------------------------------------------------------------------
  # Deck (user ownership)
  # ---------------------------------------------------------------------------

  @doc "Returns all cards of type 'admiral' that the universe_user owns."
  def list_admiral_cards_for_universe_user(universe_user_id) do
    Repo.all(
      from uc in UserCard,
        join: c in assoc(uc, :card),
        where: uc.universe_user_id == ^universe_user_id and c.type == "admiral",
        preload: [card: c],
        order_by: [asc: c.rarity, asc: c.name]
    )
  end

  @doc "Returns all admiral cards owned by a user (across their first universe_user record)."
  def list_admiral_cards_for_user(user_id) do
    universe_user = Repo.get_by(UniverseUser, user_id: user_id)
    if universe_user, do: list_admiral_cards_for_universe_user(universe_user.id), else: []
  end

  @doc "Gives a card to a universe_user. Idempotent (no duplicate)."
  def give_card_to_universe_user(universe_user_id, card_id) do
    %UserCard{}
    |> UserCard.changeset(%{universe_user_id: universe_user_id, card_id: card_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:universe_user_id, :card_id])
  end

  @doc "Checks whether a universe_user owns a given card."
  def user_owns_card?(universe_user_id, card_id) do
    Repo.exists?(
      from uc in UserCard,
        where: uc.universe_user_id == ^universe_user_id and uc.card_id == ^card_id
    )
  end
end
