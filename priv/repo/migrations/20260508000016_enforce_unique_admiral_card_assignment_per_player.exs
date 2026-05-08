defmodule NexusDownfall.Repo.Migrations.EnforceUniqueAdmiralCardAssignmentPerPlayer do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      unique_index(
        :fleets,
        [:universe_user_id, :admiral_card_id],
        where: "admiral_card_id IS NOT NULL",
        name: :fleets_universe_user_id_admiral_card_id_unique_idx
      )
    )
  end
end
