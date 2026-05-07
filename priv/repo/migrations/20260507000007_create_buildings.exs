defmodule NexusDownfall.Repo.Migrations.CreateBuildings do
  use Ecto.Migration

  def change do
    create table(:buildings) do
      add :planet_id, references(:planets, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :level, :integer, null: false, default: 0
      # When not nil, the building is being upgraded to (level + 1)
      add :construction_finish_at, :utc_datetime
      # Oban job id for cancellation support
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime)
    end

    create index(:buildings, [:planet_id])
    create unique_index(:buildings, [:planet_id, :type])
  end
end
