defmodule NexusDownfall.Repo.Migrations.CreateGalaxiesAndSystems do
  use Ecto.Migration

  def change do
    create table(:galaxies) do
      add :universe_id, references(:universes, on_delete: :delete_all), null: false
      add :number, :integer, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:galaxies, [:universe_id, :number])

    create table(:solar_systems) do
      add :galaxy_id, references(:galaxies, on_delete: :delete_all), null: false
      add :number, :integer, null: false
      # Coordinates for map rendering (optional, seeded on universe generation)
      add :x, :float
      add :y, :float
      timestamps(type: :utc_datetime)
    end

    create unique_index(:solar_systems, [:galaxy_id, :number])

    # Hyperlinks connect two solar systems (undirected edge)
    create table(:hyperlinks) do
      add :system_a_id, references(:solar_systems, on_delete: :delete_all), null: false
      add :system_b_id, references(:solar_systems, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:hyperlinks, [:system_a_id, :system_b_id])
    create index(:hyperlinks, [:system_b_id])
  end
end
