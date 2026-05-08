defmodule NexusDownfall.Repo.Migrations.BackfillColonizerForAllFleets do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO fleet_ships (fleet_id, ship_type, quantity, inserted_at, updated_at)
    SELECT f.id, 'colonizer', 1, NOW() AT TIME ZONE 'utc', NOW() AT TIME ZONE 'utc'
    FROM fleets f
    LEFT JOIN fleet_ships fs ON fs.fleet_id = f.id AND fs.ship_type = 'colonizer'
    WHERE fs.id IS NULL;
    """)

    execute("""
    UPDATE fleet_ships
    SET quantity = 1,
        updated_at = NOW() AT TIME ZONE 'utc'
    WHERE ship_type = 'colonizer'
      AND quantity < 1;
    """)
  end

  def down do
    # Intentionally no-op: this migration repairs data and should not remove ships on rollback.
    :ok
  end
end
