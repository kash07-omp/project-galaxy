defmodule NexusDownfall.Repo.Migrations.CreatePlanetDefenses do
  use Ecto.Migration

  def change do
    create table(:planet_defenses) do
      add :planet_id, references(:planets, on_delete: :delete_all), null: false
      add :defense_type, :string, null: false
      add :quantity, :integer, null: false, default: 0
      add :damaged_quantity, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:planet_defenses, [:planet_id])
    create unique_index(:planet_defenses, [:planet_id, :defense_type])

    create table(:defense_queue_items) do
      add :planet_id, references(:planets, on_delete: :delete_all), null: false
      add :defense_type, :string, null: false
      add :quantity, :integer, null: false
      add :queue_position, :integer, null: false
      add :status, :string, null: false, default: "queued"
      add :build_seconds, :integer, null: false
      add :started_at, :utc_datetime
      add :finish_at, :utc_datetime
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime)
    end

    create index(:defense_queue_items, [:planet_id])
    create index(:defense_queue_items, [:planet_id, :status])
    create unique_index(:defense_queue_items, [:planet_id, :queue_position])
  end
end
