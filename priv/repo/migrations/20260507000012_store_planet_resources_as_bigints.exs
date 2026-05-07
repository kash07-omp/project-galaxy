defmodule NexusDownfall.Repo.Migrations.StorePlanetResourcesAsBigints do
  use Ecto.Migration

  @resource_columns ~w(raw_materials microchips hydrogen food credits)a

  def up do
    Enum.each(@resource_columns, fn column ->
      execute "ALTER TABLE planets ALTER COLUMN #{column} TYPE bigint USING round(#{column})::bigint"
      execute "ALTER TABLE planets ALTER COLUMN #{column} SET DEFAULT #{default_for(column)}"
    end)
  end

  def down do
    Enum.each(@resource_columns, fn column ->
      execute "ALTER TABLE planets ALTER COLUMN #{column} TYPE double precision USING #{column}::double precision"
      execute "ALTER TABLE planets ALTER COLUMN #{column} SET DEFAULT #{default_for(column)}.0"
    end)
  end

  defp default_for(:credits), do: 1000
  defp default_for(_column), do: 500
end
