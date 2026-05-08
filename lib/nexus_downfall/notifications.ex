defmodule NexusDownfall.Notifications do
  @moduledoc """
  Notifications context.

  Stores and delivers user notifications (battle reports and future system events)
  with a lightweight query profile suitable for high-concurrency game sessions.
  """

  import Ecto.Query
  require Logger

  alias NexusDownfall.Notifications.Notification
  alias NexusDownfall.Repo

  @topbar_limit 8
  @metric_types [:combat, :espionage, :construction, :universe]

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
    try do
      Repo.all(
        from n in Notification,
          where: n.user_id == ^user_id,
          order_by: [desc: n.inserted_at, desc: n.id],
          limit: ^limit
      )
    rescue
      exception ->
        log_notification_error(:list_recent_failed, exception, %{user_id: user_id})
        []
    end
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

    try do
      Repo.all(query)
    rescue
      exception ->
        log_notification_error(:list_failed, exception, %{user_id: user_id})
        []
    end
  end

  def notification_metrics_for_user(user_id) when is_integer(user_id) do
    base = Map.new(@metric_types, &{&1, 0})

    try do
      rows =
        Repo.all(
          from n in Notification,
            where: n.user_id == ^user_id,
            group_by: n.type,
            select: {n.type, count(n.id)}
        )

      Enum.reduce(rows, base, fn {type, count}, acc ->
        Map.update!(acc, notification_metric_type(type), &(&1 + count))
      end)
      |> Map.put(:total, Enum.reduce(rows, 0, fn {_type, count}, acc -> acc + count end))
    rescue
      exception ->
        log_notification_error(:metrics_failed, exception, %{user_id: user_id})
        Map.put(base, :total, 0)
    end
  end

  def unread_notifications_count(user_id) when is_integer(user_id) do
    try do
      Repo.one(
        from n in Notification,
          where: n.user_id == ^user_id and is_nil(n.read_at),
          select: count(n.id)
      ) || 0
    rescue
      exception ->
        log_notification_error(:unread_count_failed, exception, %{user_id: user_id})
        0
    end
  end

  def get_user_notification(notification_id, user_id)
      when is_integer(notification_id) and is_integer(user_id) do
    try do
      Repo.get_by(Notification, id: notification_id, user_id: user_id)
    rescue
      exception ->
        log_notification_error(:get_failed, exception, %{
          user_id: user_id,
          notification_id: notification_id
        })

        nil
    end
  end

  def get_user_notification!(notification_id, user_id)
      when is_integer(notification_id) and is_integer(user_id) do
    case get_user_notification(notification_id, user_id) do
      nil -> raise Ecto.NoResultsError, queryable: Notification
      notification -> notification
    end
  end

  def create_notification(attrs) when is_map(attrs) do
    try do
      %Notification{}
      |> Notification.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, notification} = ok ->
          broadcast_created(notification)
          ok

        {:error, changeset} = error ->
          log_notification_error(:insert_rejected, changeset, %{
            attrs: Map.take(attrs, [:user_id, :universe_id, :type])
          })

          error
      end
    rescue
      exception ->
        log_notification_error(:insert_failed, exception, %{
          attrs: Map.take(attrs, [:user_id, :universe_id, :type])
        })

        {:error, {:insert_failed, exception}}
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
  rescue
    exception ->
      log_notification_error(:read_update_failed, exception, %{
        user_id: user_id,
        notification_id: notification_id
      })

      {:error, :read_update_failed}
  end

  def delete_notification(notification_id, user_id)
      when is_integer(notification_id) and is_integer(user_id) do
    case get_user_notification(notification_id, user_id) do
      nil ->
        {:error, :not_found}

      %Notification{} = notification ->
        case Repo.delete(notification) do
          {:ok, deleted} = ok ->
            broadcast_deleted(deleted)
            ok

          error ->
            error
        end
    end
  rescue
    exception ->
      log_notification_error(:delete_failed, exception, %{
        user_id: user_id,
        notification_id: notification_id
      })

      {:error, :delete_failed}
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

  defp broadcast_deleted(notification) do
    Phoenix.PubSub.broadcast(
      NexusDownfall.PubSub,
      notifications_topic_for_user(notification.user_id),
      {:notification_deleted, %{notification_id: notification.id, read_at: notification.read_at}}
    )
  end

  defp notification_metric_type(type) when type in ["battle_report", "combat"], do: :combat
  defp notification_metric_type("espionage"), do: :espionage
  defp notification_metric_type("construction"), do: :construction
  defp notification_metric_type(_), do: :universe

  defp log_notification_error(event, exception, metadata) do
    detail =
      case exception do
        %{__exception__: true} -> Exception.message(exception)
        _ -> inspect(exception)
      end

    Logger.error(
      "notification_error event=#{event} metadata=#{inspect(metadata)} exception=#{detail}"
    )
  end
end
