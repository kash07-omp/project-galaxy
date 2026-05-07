defmodule NexusDownfall.Repo.Migrations.AddLocaleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :locale, :string, null: false, default: "es"
    end
  end
end
