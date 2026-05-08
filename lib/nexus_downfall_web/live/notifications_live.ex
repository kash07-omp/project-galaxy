defmodule NexusDownfallWeb.NotificationsLive do
  @moduledoc "User notifications center with battle report details."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Notifications

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  @list_limit 60

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    notifications = Notifications.list_notifications_for_user(user_id, limit: @list_limit)

    {:ok,
     socket
     |> assign(:show_user_menu, false)
     |> assign(:notifications, notifications)
     |> assign(:selected_notification, List.first(notifications))
     |> assign(:page_title, gettext("Notifications"))}
  end

  def handle_params(params, _uri, socket) do
    selected = pick_selected_notification(params, socket.assigns)

    socket =
      case selected do
        %{id: id, read_at: nil} ->
          case Notifications.mark_notification_read(id, socket.assigns.current_user.id) do
            {:ok, updated} -> assign_selected(socket, updated)
            _ -> assign_selected(socket, selected)
          end

        _ ->
          assign_selected(socket, selected)
      end

    {:noreply, socket}
  end

  def handle_event("toggle_user_menu", _params, socket) do
    {:noreply, assign(socket, :show_user_menu, !socket.assigns.show_user_menu)}
  end

  def handle_info({:notification_created, notification}, socket) do
    notifications =
      [notification | Enum.reject(socket.assigns.notifications, &(&1.id == notification.id))]
      |> Enum.take(@list_limit)

    {:noreply, assign(socket, :notifications, notifications)}
  end

  def handle_info({:notification_read, %{notification_id: id, read_at: read_at}}, socket) do
    notifications =
      Enum.map(socket.assigns.notifications, fn notification ->
        if notification.id == id, do: %{notification | read_at: read_at}, else: notification
      end)

    selected =
      case socket.assigns.selected_notification do
        %{id: ^id} = notification -> %{notification | read_at: read_at}
        other -> other
      end

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:selected_notification, selected)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col overflow-hidden bg-[#050912] text-gray-100">
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        show_game_nav={false}
        notifications={@topbar_notifications}
        notifications_unread_count={@topbar_notifications_unread_count}
        show_notifications_menu={@show_notifications_menu}
      />

      <main class="flex-1 overflow-y-auto bg-[radial-gradient(circle_at_18%_12%,#12385f_0%,#081426_32%,#040912_72%,#03060d_100%)] px-4 py-4 md:px-6">
        <div class="mx-auto max-w-[1450px] space-y-4">
          <header class="rounded-2xl border border-cyan-500/25 bg-[#071325]/80 px-5 py-4 shadow-[0_18px_44px_rgba(2,8,22,0.62)]">
            <p class="text-[10px] uppercase tracking-[0.2em] text-cyan-300/80">{gettext("Command Relay")}</p>
            <h1 class="mt-1 text-2xl font-bold text-white">{gettext("Notifications")}</h1>
            <p class="mt-1 text-sm text-cyan-100/80">
              {gettext("Battle reports and strategic system alerts are stored here.")}
            </p>
          </header>

          <section class="grid gap-4 xl:grid-cols-[360px_minmax(0,1fr)]">
            <aside class="rounded-2xl border border-cyan-500/20 bg-[#081225]/90 p-3 shadow-[0_18px_44px_rgba(2,8,22,0.62)]">
              <h2 class="mb-3 px-2 text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300/80">
                {gettext("Recent Notifications")}
              </h2>

              <%= if @notifications == [] do %>
                <div class="rounded-xl border border-dashed border-cyan-600/30 bg-[#060d18]/70 p-4 text-sm text-gray-400">
                  {gettext("No notifications yet.")}
                </div>
              <% else %>
                <div class="space-y-2">
                  <%= for notification <- @notifications do %>
                    <.link
                      navigate={~p"/notifications/#{notification.id}"}
                      class={[
                        "block rounded-xl border px-3 py-2.5 transition",
                        if(@selected_notification && @selected_notification.id == notification.id,
                          do: "border-cyan-400/65 bg-cyan-900/35",
                          else: "border-cyan-500/20 bg-[#050e1c]/80 hover:border-cyan-400/45"
                        )
                      ]}
                    >
                      <div class="flex items-start justify-between gap-2">
                        <p class="text-sm font-semibold text-white">{notification_title(notification, gettext("Battle Report"))}</p>
                        <span :if={is_nil(notification.read_at)} class="mt-1 h-2 w-2 rounded-full bg-cyan-300" />
                      </div>
                      <p class="mt-1 text-xs text-gray-300">{notification_summary(notification)}</p>
                      <p class="mt-2 text-[11px] text-gray-500">{notification_time(notification.inserted_at)}</p>
                    </.link>
                  <% end %>
                </div>
              <% end %>
            </aside>

            <article class="rounded-2xl border border-cyan-500/20 bg-[#081225]/90 p-4 shadow-[0_18px_44px_rgba(2,8,22,0.62)] md:p-5">
              <%= if @selected_notification do %>
                <.notification_detail
                  notification={@selected_notification}
                  won_label={gettext("Victory")}
                  lost_label={gettext("Defeat")}
                  draw_label={gettext("Draw")}
                />
              <% else %>
                <div class="rounded-xl border border-dashed border-cyan-600/30 bg-[#060d18]/70 p-6 text-center text-gray-400">
                  {gettext("Select a notification to view details.")}
                </div>
              <% end %>
            </article>
          </section>
        </div>
      </main>
    </div>
    """
  end

  attr :notification, :map, required: true
  attr :won_label, :string, required: true
  attr :lost_label, :string, required: true
  attr :draw_label, :string, required: true

  defp notification_detail(assigns) do
    payload = assigns.notification.payload || %{}

    outcome = payload_get(payload, "outcome_for_recipient", "draw")

    outcome_label =
      case outcome do
        "victory" -> assigns.won_label
        "defeat" -> assigns.lost_label
        _ -> assigns.draw_label
      end

    attacker_losses = payload_get(payload, "attacker_losses", [])
    defender_losses = payload_get(payload, "defender_losses", [])
    attacker_cost = payload_get(payload, "attacker_total_cost", %{})
    defender_cost = payload_get(payload, "defender_total_cost", %{})
    looted = payload_get(payload, "looted_resources", %{})

    assigns =
      assigns
      |> assign(:payload, payload)
      |> assign(:outcome_label, outcome_label)
      |> assign(:attacker_losses, attacker_losses)
      |> assign(:defender_losses, defender_losses)
      |> assign(:attacker_cost, attacker_cost)
      |> assign(:defender_cost, defender_cost)
      |> assign(:looted, looted)

    ~H"""
    <div class="space-y-4">
      <header class="rounded-xl border border-cyan-500/25 bg-[#051021]/75 p-4">
        <p class="text-[10px] uppercase tracking-[0.18em] text-cyan-300/80">{gettext("Battle Report")}</p>
        <h2 class="mt-1 text-xl font-bold text-white">{notification_title(@notification, gettext("Battle Report"))}</h2>
        <p class="mt-1 text-sm text-cyan-100/80">
          {gettext("Outcome")}: <span class="font-semibold text-cyan-200">{@outcome_label}</span>
        </p>
        <p class="mt-1 text-xs text-gray-400">
          {gettext("Rounds")}: {payload_get(@payload, "rounds", 0)} · {gettext("Mission")}: #{payload_get(@payload, "mission_id", "-")}
        </p>
      </header>

      <div class="grid gap-3 md:grid-cols-2">
        <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85 p-3">
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{gettext("Attacker Losses")}</h3>
          <ul class="mt-2 space-y-1 text-sm text-gray-200">
            <%= if @attacker_losses == [] do %>
              <li class="text-gray-500">{gettext("No losses")}</li>
            <% else %>
              <%= for row <- @attacker_losses do %>
                <li>{loss_row(row)}</li>
              <% end %>
            <% end %>
          </ul>
        </section>

        <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85 p-3">
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{gettext("Defender Losses")}</h3>
          <ul class="mt-2 space-y-1 text-sm text-gray-200">
            <%= if @defender_losses == [] do %>
              <li class="text-gray-500">{gettext("No losses")}</li>
            <% else %>
              <%= for row <- @defender_losses do %>
                <li>{loss_row(row)}</li>
              <% end %>
            <% end %>
          </ul>
        </section>
      </div>

      <div class="grid gap-3 md:grid-cols-3">
        <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85 p-3 text-sm">
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{gettext("Attacker Cost")}</h3>
          <p class="mt-2 text-gray-200">{resource_line(@attacker_cost)}</p>
        </section>

        <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85 p-3 text-sm">
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{gettext("Defender Cost")}</h3>
          <p class="mt-2 text-gray-200">{resource_line(@defender_cost)}</p>
        </section>

        <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85 p-3 text-sm">
          <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{gettext("Looted Resources")}</h3>
          <p class="mt-2 text-gray-200">{resource_line(@looted)}</p>
        </section>
      </div>
    </div>
    """
  end

  defp assign_selected(socket, nil), do: assign(socket, :selected_notification, nil)

  defp assign_selected(socket, selected) do
    notifications =
      Enum.map(socket.assigns.notifications, fn notification ->
        if notification.id == selected.id, do: selected, else: notification
      end)

    socket
    |> assign(:notifications, notifications)
    |> assign(:selected_notification, selected)
  end

  defp pick_selected_notification(%{"id" => id_param}, assigns) do
    with {id, ""} <- Integer.parse(id_param),
         %{} = notification <- Notifications.get_user_notification(id, assigns.current_user.id) do
      notification
    else
      _ -> List.first(assigns.notifications)
    end
  end

  defp pick_selected_notification(_params, assigns), do: List.first(assigns.notifications)

  defp payload_get(payload, key, default) when is_map(payload) do
    Map.get(payload, key, Map.get(payload, maybe_existing_atom(key), default))
  end

  defp maybe_existing_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> nil
    end
  end

  defp maybe_existing_atom(_), do: nil

  defp notification_title(notification, fallback) do
    case notification.type do
      "battle_report" ->
        payload = notification.payload || %{}

        case payload_get(payload, "outcome_for_recipient", "draw") do
          "victory" -> gettext("Battle won")
          "defeat" -> gettext("Battle lost")
          _ -> gettext("Battle ended in draw")
        end

      _ ->
        notification.title || fallback
    end
  end

  defp notification_summary(notification) do
    case notification.type do
      "battle_report" ->
        payload = notification.payload || %{}
        rounds = payload_get(payload, "rounds", 0)

        gettext("%{rounds} rounds resolved.", rounds: rounds)

      _ ->
        notification.summary
    end
  end

  defp loss_row(row) when is_map(row) do
    unit = row["unit_type"] || row[:unit_type] || "unit"
    lost = row["lost"] || row[:lost] || 0
    "#{String.replace(unit, "_", " ")} x#{lost}"
  end

  defp resource_line(resources) when is_map(resources) do
    raw = resources["raw_materials"] || resources[:raw_materials] || 0
    chips = resources["microchips"] || resources[:microchips] || 0
    hydro = resources["hydrogen"] || resources[:hydrogen] || 0

    gettext("RM %{raw} · MC %{chips} · H2 %{hydro}", raw: raw, chips: chips, hydro: hydro)
  end

  defp notification_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp notification_time(_), do: "-"
end
