defmodule NexusDownfall.Repo.Migrations.CreateUniverses do
  use Ecto.Migration

  def change do
    # Status enum: :open (accepting players), :running, :ended
    create table(:universes) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :status, :string, null: false, default: "open"
      # Configuration overrides — stored as JSON map
      add :settings, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:universes, [:slug])
  end
end
