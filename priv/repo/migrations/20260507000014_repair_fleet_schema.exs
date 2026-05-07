defmodule NexusDownfall.Repo.Migrations.RepairFleetSchema do
  use Ecto.Migration

  def change do
    alter table(:fleets) do
      add_if_not_exists :admiral_name, :string
      add_if_not_exists :status, :string, null: false, default: "idle"
    end

    create_if_not_exists table(:shipyard_queue_items) do
      add :planet_id, references(:planets, on_delete: :delete_all), null: false
      add :fleet_id, references(:fleets, on_delete: :delete_all), null: false
      add :ship_type, :string, null: false
      add :quantity, :integer, null: false
      add :queue_position, :integer, null: false
      add :status, :string, null: false, default: "queued"
      add :build_seconds, :integer, null: false
      add :started_at, :utc_datetime
      add :finish_at, :utc_datetime
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:fleets, [:universe_user_id])
    create_if_not_exists index(:fleets, [:home_planet_id])
    create_if_not_exists unique_index(:fleets, [:universe_user_id, :name])

    create_if_not_exists index(:fleet_ships, [:fleet_id])
    create_if_not_exists unique_index(:fleet_ships, [:fleet_id, :ship_type])

    create_if_not_exists index(:shipyard_queue_items, [:planet_id])
    create_if_not_exists index(:shipyard_queue_items, [:fleet_id])
    create_if_not_exists index(:shipyard_queue_items, [:planet_id, :status])
    create_if_not_exists unique_index(:shipyard_queue_items, [:planet_id, :queue_position])
  end
end
