defmodule NexusDownfall.Accounts.UniverseUser do
  @moduledoc """
  Join record linking a global `User` to a specific `Universe`.

  Each `UniverseUser` represents a player's presence in one server/universe.
  A user can have at most one `UniverseUser` per universe.

  Contains per-universe state: username (alias), score, karma, diplomatic points.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "universe_users" do
    field :username, :string
    field :score, :integer, default: 0
    field :karma, :integer, default: 0
    field :diplomatic_points, :integer, default: 0
    field :joined_at, :utc_datetime

    belongs_to :user, NexusDownfall.Accounts.User
    belongs_to :universe, NexusDownfall.Universe.UniverseRecord, foreign_key: :universe_id
    has_many :planets, NexusDownfall.Planets.Planet

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for joining a universe. Requires a username that is unique within
  the universe.
  """
  def join_changeset(universe_user, attrs) do
    universe_user
    |> cast(attrs, [:username, :user_id, :universe_id, :joined_at])
    |> validate_required([:username, :user_id, :universe_id, :joined_at])
    |> validate_length(:username, min: 3, max: 24)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_\- ]+$/,
      message: "only letters, numbers, spaces, underscores and hyphens allowed"
    )
    |> unique_constraint([:user_id, :universe_id],
      message: "you have already joined this universe"
    )
    |> unique_constraint([:universe_id, :username],
      message: "username already taken in this universe"
    )
  end
end
