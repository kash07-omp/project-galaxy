defmodule NexusDownfallWeb.NotificationsLiveTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias NexusDownfall.Accounts
  alias NexusDownfall.Notifications
  alias NexusDownfall.Notifications.Notification
  alias NexusDownfall.Repo

  defp create_user(locale \\ "en") do
    {:ok, user} =
      Accounts.register_user(%{
        email: "notifications-live-#{System.unique_integer([:positive])}@test.com",
        password: "supersecretpassword123"
      })

    {:ok, user} = Accounts.update_user_locale(user, locale)
    user
  end

  defp log_in(conn, user) do
    token = Accounts.generate_user_session_token(user)
    Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})
  end

  defp create_battle_notification(user) do
    {:ok, notification} =
      Notifications.create_notification(%{
        user_id: user.id,
        type: "battle_report",
        title: "Battle Report",
        summary: "Combat mission resolved.",
        payload: %{
          "rounds" => 1,
          "outcome_for_recipient" => "victory",
          "origin_planet_name" => "Strike Alpha",
          "target_planet_name" => "Shield Beta",
          "mission_id" => 18700,
          "looted_resources" => %{
            "raw_materials" => 18_700,
            "microchips" => 2_500,
            "hydrogen" => 0,
            "food" => 0,
            "credits" => 0
          },
          "attacker_total_cost" => %{"raw_materials" => 0, "microchips" => 0, "hydrogen" => 0},
          "defender_total_cost" => %{
            "raw_materials" => 3_600,
            "microchips" => 600,
            "hydrogen" => 0
          },
          "attacker_units" => [
            %{
              "unit_type" => "corvette",
              "kind" => "ship",
              "class" => "Medium",
              "name" => "Corvette",
              "icon_path" => "/images/ships/ship-a.svg",
              "thumbnail_path" => "/images/ships/valkyr.jpg",
              "before" => 18_700,
              "after" => 18_699,
              "lost" => 1
            }
          ],
          "defender_units" => [
            %{
              "unit_type" => "missile_platform",
              "kind" => "defense",
              "class" => "Light",
              "name" => "Missile Platform",
              "icon_path" => "/images/planet-images/defense-center.png",
              "before" => 2,
              "after" => 0,
              "lost" => 2
            }
          ],
          "round_summaries" => [
            %{
              "round" => 1,
              "attacker_power" => 18_700,
              "defender_power" => 350,
              "no_defenders" => false,
              "attacker_losses" => [
                %{"unit_type" => "corvette", "name" => "Corvette", "lost" => 1}
              ],
              "defender_losses" => [
                %{"unit_type" => "missile_platform", "name" => "Missile Platform", "lost" => 2}
              ]
            }
          ]
        }
      })

    notification
  end

  test "renders universe navigation, battle detail columns and localized numbers", %{conn: conn} do
    user = create_user("es")
    notification = create_battle_notification(user)
    conn = log_in(conn, user)

    {:ok, _live_view, html} = live(conn, ~p"/notifications/#{notification.id}")

    assert html =~ ~s(href="/fleet")
    assert html =~ "Corvette"
    assert html =~ "Missile Platform"
    assert html =~ "valkyr.jpg"
    assert html =~ "18.700"
  end

  test "deletes a notification from the notifications page", %{conn: conn} do
    user = create_user()
    notification = create_battle_notification(user)
    conn = log_in(conn, user)

    {:ok, live_view, html} = live(conn, ~p"/notifications/#{notification.id}")
    assert html =~ "Corvette"

    live_view
    |> element("button[phx-click='delete_notification'][phx-value-id='#{notification.id}']")
    |> render_click()

    refute Repo.get(Notification, notification.id)
    refute render(live_view) =~ "Corvette"
  end
end
