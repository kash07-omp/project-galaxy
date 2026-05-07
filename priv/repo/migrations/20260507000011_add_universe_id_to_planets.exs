defmodule NexusDownfall.Repo.Migrations.AddUniverseIdToPlanets do
  use Ecto.Migration

  def up do
    alter table(:planets) do
      add :universe_id, references(:universes, on_delete: :delete_all)
    end

    execute """
    UPDATE planets AS p
    SET universe_id = g.universe_id
    FROM solar_systems AS s
    JOIN galaxies AS g ON g.id = s.galaxy_id
    WHERE p.solar_system_id = s.id
      AND p.universe_id IS NULL
    """

    execute "ALTER TABLE planets ALTER COLUMN universe_id SET NOT NULL"

    create index(:planets, [:universe_id])
    create index(:planets, [:universe_id, :universe_user_id])
    create index(:planets, [:universe_id, :solar_system_id])
  end

  def down do
    drop index(:planets, [:universe_id, :solar_system_id])
    drop index(:planets, [:universe_id, :universe_user_id])
    drop index(:planets, [:universe_id])

    alter table(:planets) do
      remove :universe_id
    end
  end
end
