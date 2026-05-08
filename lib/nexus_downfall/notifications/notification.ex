defmodule NexusDownfall.Notifications.Notification do
  @moduledoc "User-facing notification entity (battle reports, system alerts, etc.)."

  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :summary, :string
    field :payload, :map, default: %{}
    field :read_at, :utc_datetime

    belongs_to :user, NexusDownfall.Accounts.User
    belongs_to :universe, NexusDownfall.Universe.UniverseRecord

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :universe_id, :type, :title, :summary, :payload, :read_at])
    |> validate_required([:user_id, :type, :title, :summary, :payload])
    |> validate_length(:type, min: 2, max: 64)
    |> validate_length(:title, min: 2, max: 180)
    |> validate_length(:summary, min: 2, max: 280)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:universe_id)
  end
end
