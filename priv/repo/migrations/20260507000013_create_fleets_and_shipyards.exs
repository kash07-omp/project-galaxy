defmodule NexusDownfall.Repo.Migrations.CreateFleetsAndShipyards do
  use Ecto.Migration

  def change do
    create table(:fleets) do
      add :name, :string, null: false
      add :admiral_name, :string
      add :status, :string, null: false, default: "idle"
      add :universe_user_id, references(:universe_users, on_delete: :delete_all), null: false
      add :home_planet_id, references(:planets, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:fleets, [:universe_user_id])
    create index(:fleets, [:home_planet_id])
    create unique_index(:fleets, [:universe_user_id, :name])

    create table(:fleet_ships) do
      add :fleet_id, references(:fleets, on_delete: :delete_all), null: false
      add :ship_type, :string, null: false
      add :quantity, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:fleet_ships, [:fleet_id])
    create unique_index(:fleet_ships, [:fleet_id, :ship_type])

    create table(:shipyard_queue_items) do
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

    create index(:shipyard_queue_items, [:planet_id])
    create index(:shipyard_queue_items, [:fleet_id])
    create index(:shipyard_queue_items, [:planet_id, :status])
    create unique_index(:shipyard_queue_items, [:planet_id, :queue_position])
  end
end
