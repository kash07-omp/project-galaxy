defmodule NexusDownfall.Repo.Migrations.CreateCardsSystem do
  use Ecto.Migration

  def change do
    # Master card catalog (admin-seeded, global across all universes)
    create table(:cards) do
      add :type, :string, null: false       # "admiral" | "ship" | "equipment" | ...
      add :slug, :string, null: false       # unique human key: "queen", "admiral_alpha"
      add :name, :string, null: false
      add :description, :text
      add :image_path, :string              # relative to /images/: "cards/admiral-0.jpg"
      add :rarity, :string, null: false, default: "common"
      # Generic bonus payload. Structure:
      # %{"effects" => [%{"type" => "stat_bonus", "stat" => "evasion",
      #   "ship_types" => [...], "modifier" => "percentage", "value" => N}]}
      add :bonuses, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cards, [:slug])
    create index(:cards, [:type])

    # Per-universe-user card ownership (deck)
    create table(:user_cards) do
      add :universe_user_id, references(:universe_users, on_delete: :delete_all), null: false
      add :card_id, references(:cards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_cards, [:universe_user_id, :card_id])
    create index(:user_cards, [:universe_user_id])
    create index(:user_cards, [:card_id])

    # Legacy compatibility: some local DBs may already have admiral_card_id as string.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'fleets'
          AND column_name = 'admiral_card_id'
          AND data_type IN ('character varying', 'text')
      ) THEN
        ALTER TABLE fleets DROP COLUMN admiral_card_id;
      END IF;
    END $$;
    """)

    # Link fleet to an admiral card (nullable)
    alter table(:fleets) do
      add_if_not_exists :admiral_card_id, references(:cards, on_delete: :nilify_all), null: true
    end
  end
end
