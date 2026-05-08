defmodule NexusDownfallWeb.NotificationHooks do
  @moduledoc """
  Shared LiveView hook for topbar notifications state.

  It keeps topbar counters/lists in socket assigns and listens to PubSub updates.
  """

  import Phoenix.Component, only: [assign: 3]

  alias NexusDownfall.Notifications

  @topbar_limit 8

  def on_mount(:default, _params, _session, socket) do
    user_id = socket.assigns.current_user.id
    payload = Notifications.topbar_payload_for_user(user_id, limit: @topbar_limit)

    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(
        NexusDownfall.PubSub,
        Notifications.notifications_topic_for_user(user_id)
      )
    end

    socket =
      socket
      |> assign(:topbar_notifications, payload.notifications)
      |> assign(:topbar_notifications_unread_count, payload.unread_count)
      |> assign(:show_notifications_menu, false)
      |> Phoenix.LiveView.attach_hook(
        :topbar_notifications_events,
        :handle_event,
        &handle_event/3
      )
      |> Phoenix.LiveView.attach_hook(:topbar_notifications_info, :handle_info, &handle_info/2)

    {:cont, socket}
  end

  defp handle_event("toggle_notifications_menu", _params, socket) do
    {:halt, assign(socket, :show_notifications_menu, !socket.assigns.show_notifications_menu)}
  end

  defp handle_event("close_notifications_menu", _params, socket) do
    {:halt, assign(socket, :show_notifications_menu, false)}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp handle_info({:notification_created, notification}, socket) do
    unread_increment = if is_nil(notification.read_at), do: 1, else: 0

    notifications =
      [
        notification
        | Enum.reject(socket.assigns.topbar_notifications, &(&1.id == notification.id))
      ]
      |> Enum.take(@topbar_limit)

    socket =
      socket
      |> assign(:topbar_notifications, notifications)
      |> assign(
        :topbar_notifications_unread_count,
        socket.assigns.topbar_notifications_unread_count + unread_increment
      )

    {:cont, socket}
  end

  defp handle_info({:notification_read, %{notification_id: id, read_at: read_at}}, socket) do
    {notifications, decremented?} =
      Enum.map_reduce(socket.assigns.topbar_notifications, false, fn notification, dec? ->
        if notification.id == id and is_nil(notification.read_at) do
          {%{notification | read_at: read_at}, true}
        else
          {notification, dec?}
        end
      end)

    unread_count =
      if decremented? do
        max(socket.assigns.topbar_notifications_unread_count - 1, 0)
      else
        socket.assigns.topbar_notifications_unread_count
      end

    socket =
      socket
      |> assign(:topbar_notifications, notifications)
      |> assign(:topbar_notifications_unread_count, unread_count)

    {:cont, socket}
  end

  defp handle_info({:notification_deleted, %{notification_id: id, read_at: read_at}}, socket) do
    notifications = Enum.reject(socket.assigns.topbar_notifications, &(&1.id == id))

    unread_count =
      if is_nil(read_at) do
        max(socket.assigns.topbar_notifications_unread_count - 1, 0)
      else
        socket.assigns.topbar_notifications_unread_count
      end

    socket =
      socket
      |> assign(:topbar_notifications, notifications)
      |> assign(:topbar_notifications_unread_count, unread_count)

    {:cont, socket}
  end

  defp handle_info(_message, socket), do: {:cont, socket}
end
