defmodule NexusDownfall.Repo.Migrations.AddAccountNameAndSpeciesFields do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :account_name, :citext
    end

    execute """
    UPDATE users
    SET account_name = split_part(email::text, '@', 1)
    WHERE account_name IS NULL
    """

    alter table(:users) do
      modify :account_name, :citext, null: false
    end

    create unique_index(:users, [:account_name])

    alter table(:universe_users) do
      add :species, :string, null: false, default: "human"
    end

    create index(:universe_users, [:species])
  end

  def down do
    drop index(:universe_users, [:species])

    alter table(:universe_users) do
      remove :species
    end

    drop unique_index(:users, [:account_name])

    alter table(:users) do
      remove :account_name
    end
  end
end
