defmodule NexusDownfall.Universe.Hyperlink do
  @moduledoc """
  A bidirectional hyperlane connecting two solar systems within the same galaxy.

  Fleets may travel along a hyperlink in either direction. The pair
  `(system_a_id, system_b_id)` is stored with `system_a_id < system_b_id` to
  enforce uniqueness.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NexusDownfall.Universe.SolarSystem

  schema "hyperlinks" do
    belongs_to :system_a, SolarSystem, foreign_key: :system_a_id
    belongs_to :system_b, SolarSystem, foreign_key: :system_b_id

    timestamps(type: :utc_datetime)
  end

  def changeset(hyperlink, attrs) do
    hyperlink
    |> cast(attrs, [:system_a_id, :system_b_id])
    |> validate_required([:system_a_id, :system_b_id])
    |> validate_different_systems()
    |> unique_constraint([:system_a_id, :system_b_id])
  end

  defp validate_different_systems(changeset) do
    a = get_field(changeset, :system_a_id)
    b = get_field(changeset, :system_b_id)

    if a != nil and b != nil and a == b do
      add_error(changeset, :system_b_id, "must be different from system_a")
    else
      changeset
    end
  end
end
