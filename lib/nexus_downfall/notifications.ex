defmodule NexusDownfall.Notifications do
  @moduledoc """
  Notifications context.

  Stores and delivers user notifications (battle reports and future system events)
  with a lightweight query profile suitable for high-concurrency game sessions.
  """

  import Ecto.Query

  alias NexusDownfall.Notifications.Notification
  alias NexusDownfall.Repo

  @topbar_limit 8

  def notifications_topic_for_user(user_id) when is_integer(user_id) do
    "notifications:user:" <> Integer.to_string(user_id)
  end

  def topbar_payload_for_user(user_id, opts \\ []) when is_integer(user_id) do
    limit = Keyword.get(opts, :limit, @topbar_limit)

    %{
      notifications: list_recent_notifications_for_user(user_id, limit),
      unread_count: unread_notifications_count(user_id)
    }
  end

  def list_recent_notifications_for_user(user_id, limit \\ @topbar_limit)
      when is_integer(user_id) and is_integer(limit) and limit > 0 do
    Repo.all(
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at, desc: n.id],
        limit: ^limit
    )
  end

  def list_notifications_for_user(user_id, opts \\ []) when is_integer(user_id) do
    limit = Keyword.get(opts, :limit, 50)

    query =
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at, desc: n.id],
        limit: ^limit

    query =
      case Keyword.get(opts, :before_id) do
        id when is_integer(id) -> from n in query, where: n.id < ^id
        _ -> query
      end

    Repo.all(query)
  end

  def unread_notifications_count(user_id) when is_integer(user_id) do
    Repo.one(
      from n in Notification,
        where: n.user_id == ^user_id and is_nil(n.read_at),
        select: count(n.id)
    ) || 0
  end

  def get_user_notification(notification_id, user_id)
      when is_integer(notification_id) and is_integer(user_id) do
    Repo.get_by(Notification, id: notification_id, user_id: user_id)
  end

  def get_user_notification!(notification_id, user_id)
      when is_integer(notification_id) and is_integer(user_id) do
    Repo.get_by!(Notification, id: notification_id, user_id: user_id)
  end

  def create_notification(attrs) when is_map(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} = ok ->
        broadcast_created(notification)
        ok

      error ->
        error
    end
  end

  def mark_notification_read(notification_id, user_id)
      when is_integer(notification_id) and is_integer(user_id) do
    case get_user_notification(notification_id, user_id) do
      nil ->
        {:error, :not_found}

      %Notification{read_at: %DateTime{}} = notification ->
        {:ok, notification}

      %Notification{} = notification ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        notification
        |> Notification.changeset(%{read_at: now})
        |> Repo.update()
        |> case do
          {:ok, updated} = ok ->
            broadcast_read(updated)
            ok

          error ->
            error
        end
    end
  end

  defp broadcast_created(notification) do
    Phoenix.PubSub.broadcast(
      NexusDownfall.PubSub,
      notifications_topic_for_user(notification.user_id),
      {:notification_created, notification}
    )
  end

  defp broadcast_read(notification) do
    Phoenix.PubSub.broadcast(
      NexusDownfall.PubSub,
      notifications_topic_for_user(notification.user_id),
      {:notification_read, %{notification_id: notification.id, read_at: notification.read_at}}
    )
  end
end
