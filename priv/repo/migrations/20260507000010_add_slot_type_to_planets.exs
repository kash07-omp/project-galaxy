defmodule NexusDownfall.Repo.Migrations.AddSlotTypeToPlanets do
  use Ecto.Migration

  def change do
    alter table(:planets) do
      add :slot_type, :string, null: false, default: "planet"
      add :planet_subtype, :string, null: true
    end

    create index(:planets, [:solar_system_id, :slot_type])
  end
end
