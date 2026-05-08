defmodule NexusDownfall.Repo.Migrations.CreateFleetMissions do
  use Ecto.Migration

  def change do
    create table(:fleet_missions) do
      add :mission_type, :string, null: false
      add :phase, :string, null: false, default: "outbound"
      add :result_reason, :string

      add :route_system_ids, {:array, :bigint}, null: false, default: []

      add :outbound_travel_seconds, :integer, null: false
      add :colonization_seconds, :integer, null: false
      add :return_travel_seconds, :integer, null: false

      add :hydrogen_cost, :bigint, null: false

      add :outbound_arrival_at, :utc_datetime, null: false
      add :colonization_complete_at, :utc_datetime
      add :return_arrival_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :current_oban_job_id, :bigint

      add :fleet_id, references(:fleets, on_delete: :delete_all), null: false
      add :origin_planet_id, references(:planets, on_delete: :nilify_all), null: false
      add :target_planet_id, references(:planets, on_delete: :nilify_all), null: false
      add :universe_user_id, references(:universe_users, on_delete: :delete_all), null: false
      add :universe_id, references(:universes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:fleet_missions, [:fleet_id])
    create index(:fleet_missions, [:universe_id, :phase])
    create index(:fleet_missions, [:target_planet_id, :phase])
    create index(:fleet_missions, [:outbound_arrival_at])
    create index(:fleet_missions, [:colonization_complete_at])
    create index(:fleet_missions, [:return_arrival_at])

    create unique_index(:fleet_missions, [:fleet_id],
             where: "phase IN ('outbound', 'colonizing', 'returning')",
             name: :fleet_missions_one_active_per_fleet_idx
           )
  end
end
