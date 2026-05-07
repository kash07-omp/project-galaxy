defmodule NexusDownfall.Universe.SolarSystem do
  @moduledoc "Solar system within a galaxy. Contains planets."

  use Ecto.Schema
  import Ecto.Changeset

  schema "solar_systems" do
    field :number, :integer
    field :x, :float
    field :y, :float

    belongs_to :galaxy, NexusDownfall.Universe.Galaxy
    has_many :planets, NexusDownfall.Planets.Planet
    has_many :hyperlinks_a, NexusDownfall.Universe.Hyperlink, foreign_key: :system_a_id
    has_many :hyperlinks_b, NexusDownfall.Universe.Hyperlink, foreign_key: :system_b_id

    timestamps(type: :utc_datetime)
  end

  def changeset(system, attrs) do
    system
    |> cast(attrs, [:number, :galaxy_id, :x, :y])
    |> validate_required([:number, :galaxy_id])
    |> unique_constraint([:galaxy_id, :number])
  end
end
