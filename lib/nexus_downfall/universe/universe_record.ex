defmodule NexusDownfall.Universe.UniverseRecord do
  @moduledoc """
  Ecto schema for the `universes` table.

  Named `UniverseRecord` (not `Universe`) to avoid collision with the
  `NexusDownfall.Universe` context module in the same directory.

  `status` lifecycle: `"open"` → `"running"` → `"ended"`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(open running ended)

  schema "universes" do
    field :name, :string
    field :slug, :string
    field :status, :string, default: "open"
    field :settings, :map, default: %{}

    has_many :universe_users, NexusDownfall.Accounts.UniverseUser, foreign_key: :universe_id
    has_many :galaxies, NexusDownfall.Universe.Galaxy, foreign_key: :universe_id

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a universe."
  def creation_changeset(universe, attrs) do
    universe
    |> cast(attrs, [:name, :slug, :status, :settings])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/,
      message: "only lowercase letters, numbers and hyphens"
    )
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:slug)
  end

  @doc "Changeset for status transitions."
  def status_changeset(universe, attrs) do
    universe
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
