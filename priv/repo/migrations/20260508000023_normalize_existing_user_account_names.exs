defmodule NexusDownfall.Repo.Migrations.NormalizeExistingUserAccountNames do
  use Ecto.Migration

  def up do
    execute """
    WITH prepared AS (
      SELECT
        id,
        LEFT(TRIM(REGEXP_REPLACE(COALESCE(account_name::text, ''), '[^A-Za-z0-9_\\- ]', '', 'g')), 24) AS cleaned
      FROM users
    ),
    base_names AS (
      SELECT
        id,
        CASE
          WHEN cleaned = '' THEN LEFT('Commander-' || id::text, 24)
          ELSE cleaned
        END AS base_name
      FROM prepared
    ),
    dedup AS (
      SELECT
        id,
        base_name,
        ROW_NUMBER() OVER (PARTITION BY LOWER(base_name) ORDER BY id) AS rn
      FROM base_names
    ),
    final_names AS (
      SELECT
        id,
        CASE
          WHEN rn = 1 THEN base_name
          ELSE LEFT(base_name, GREATEST(1, 24 - LENGTH(id::text) - 1)) || '-' || id::text
        END AS final_name
      FROM dedup
    )
    UPDATE users AS u
    SET account_name = f.final_name
    FROM final_names AS f
    WHERE u.id = f.id
    """
  end

  def down do
    :ok
  end
end
