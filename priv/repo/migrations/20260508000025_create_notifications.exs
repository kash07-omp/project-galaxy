defmodule NexusDownfall.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :universe_id, references(:universes, on_delete: :nilify_all)
      add :type, :string, null: false
      add :title, :string, null: false
      add :summary, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id, :inserted_at])
    create index(:notifications, [:user_id, :read_at, :inserted_at])
    create index(:notifications, [:universe_id])
  end
end
