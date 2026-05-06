defmodule NexusDownfall.Repo.Migrations.CreateUniverseUsers do
  use Ecto.Migration

  def change do
    create table(:universe_users) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :universe_id, references(:universes, on_delete: :delete_all), null: false
      add :username, :string, null: false
      add :score, :bigint, null: false, default: 0
      add :karma, :integer, null: false, default: 0
      add :diplomatic_points, :integer, null: false, default: 0
      add :joined_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:universe_users, [:user_id, :universe_id])
    create unique_index(:universe_users, [:universe_id, :username])
    create index(:universe_users, [:universe_id, :score])
  end
end
