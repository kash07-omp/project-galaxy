defmodule NexusDownfall.Universe.Galaxy do
  @moduledoc "Galaxy within a universe. Contains solar systems."

  use Ecto.Schema
  import Ecto.Changeset

  schema "galaxies" do
    field :number, :integer

    belongs_to :universe, NexusDownfall.Universe.UniverseRecord, foreign_key: :universe_id
    has_many :solar_systems, NexusDownfall.Universe.SolarSystem

    timestamps(type: :utc_datetime)
  end

  def changeset(galaxy, attrs) do
    galaxy
    |> cast(attrs, [:number, :universe_id])
    |> validate_required([:number, :universe_id])
    |> unique_constraint([:universe_id, :number])
  end
end
