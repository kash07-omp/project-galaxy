defmodule NexusDownfall.NotificationsTest do
  use NexusDownfall.DataCase, async: true

  alias NexusDownfall.Accounts
  alias NexusDownfall.Notifications
  alias NexusDownfall.Notifications.Notification
  alias NexusDownfall.Repo

  defp create_user(email_prefix) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "#{email_prefix}-#{System.unique_integer([:positive])}@test.com",
        password: "supersecretpassword123"
      })

    user
  end

  defp create_notification(user, attrs \\ %{}) do
    {:ok, notification} =
      Notifications.create_notification(
        Map.merge(
          %{
            user_id: user.id,
            type: "battle_report",
            title: "Battle Report",
            summary: "Combat mission resolved.",
            payload: %{"rounds" => 1}
          },
          attrs
        )
      )

    notification
  end

  test "metrics group combat aliases and universe fallback in one aggregate view" do
    user = create_user("notifications-metrics")

    create_notification(user, %{type: "battle_report"})
    create_notification(user, %{type: "combat"})
    create_notification(user, %{type: "espionage"})
    create_notification(user, %{type: "construction"})
    create_notification(user, %{type: "system"})

    assert %{
             combat: 2,
             espionage: 1,
             construction: 1,
             universe: 1,
             total: 5
           } = Notifications.notification_metrics_for_user(user.id)
  end

  test "delete notification enforces ownership and removes the row" do
    owner = create_user("notifications-owner")
    stranger = create_user("notifications-stranger")
    notification = create_notification(owner)

    assert {:error, :not_found} = Notifications.delete_notification(notification.id, stranger.id)
    assert Repo.get(Notification, notification.id)

    assert {:ok, deleted} = Notifications.delete_notification(notification.id, owner.id)
    assert deleted.id == notification.id
    refute Repo.get(Notification, notification.id)
  end
end
