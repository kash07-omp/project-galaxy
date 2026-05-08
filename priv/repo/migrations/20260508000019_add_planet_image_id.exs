defmodule NexusDownfall.Repo.Migrations.AddPlanetImageId do
  use Ecto.Migration

  def change do
    alter table(:planets) do
      add :planet_image_id, :integer, default: 1, null: false
    end

    # Backfill existing planets with deterministic image IDs
    # Image ID is (planet_id - 1) mod 60 + 1 (maps to images 1-60)
    execute(
      "UPDATE planets SET planet_image_id = ((id - 1) % 60) + 1",
      "UPDATE planets SET planet_image_id = 1"
    )
  end
end
