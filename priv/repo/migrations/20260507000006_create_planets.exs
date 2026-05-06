defmodule NexusDownfall.Repo.Migrations.CreatePlanets do
  use Ecto.Migration

  def change do
    create table(:planets) do
      add :solar_system_id, references(:solar_systems, on_delete: :delete_all), null: false
      add :universe_user_id, references(:universe_users, on_delete: :nilify_all)
      add :name, :string, null: false
      # Orbital position (1 = closest to star)
      add :orbit_position, :integer, null: false
      # Region slot on planet (1..3)
      add :region, :integer, null: false, default: 1
      # Resource stockpiles (stored as floats for fractional accumulation)
      add :raw_materials, :float, null: false, default: 500.0
      add :microchips, :float, null: false, default: 500.0
      add :hydrogen, :float, null: false, default: 500.0
      add :food, :float, null: false, default: 500.0
      add :credits, :float, null: false, default: 1000.0
      add :population, :bigint, null: false, default: 100
      # Timestamp of last resource tick computation (for offline accumulation)
      add :last_tick_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:planets, [:solar_system_id])
    create index(:planets, [:universe_user_id])
    create unique_index(:planets, [:solar_system_id, :orbit_position, :region])
  end
end
