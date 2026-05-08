defmodule NexusDownfall.Repo.Migrations.AddTransportCargoToFleetMissions do
  use Ecto.Migration

  def change do
    alter table(:fleet_missions) do
      add :cargo_raw_materials, :bigint, null: false, default: 0
      add :cargo_microchips, :bigint, null: false, default: 0
      add :cargo_hydrogen, :bigint, null: false, default: 0
      add :cargo_food, :bigint, null: false, default: 0
      add :cargo_credits, :bigint, null: false, default: 0
    end
  end
end
