defmodule NexusDownfallWeb.NotificationsLive do
  @moduledoc "User notifications center with battle report details."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Notifications

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  @list_limit 60
  @resource_fields ["raw_materials", "microchips", "hydrogen", "food", "credits"]

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    notifications = Notifications.list_notifications_for_user(user_id, limit: @list_limit)

    {:ok,
     socket
     |> assign(:show_user_menu, false)
     |> assign(:notifications, notifications)
     |> assign(:notification_metrics, Notifications.notification_metrics_for_user(user_id))
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

  def handle_event("delete_notification", %{"id" => id_param}, socket) do
    with {id, ""} <- Integer.parse(id_param),
         {:ok, deleted} <- Notifications.delete_notification(id, socket.assigns.current_user.id) do
      {:noreply, socket |> remove_notification(deleted.id) |> refresh_notification_metrics()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Notification could not be deleted."))}
    end
  end

  def handle_info({:notification_created, notification}, socket) do
    notifications =
      [notification | Enum.reject(socket.assigns.notifications, &(&1.id == notification.id))]
      |> Enum.take(@list_limit)

    selected = socket.assigns.selected_notification || List.first(notifications)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:selected_notification, selected)
     |> refresh_notification_metrics()}
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

  def handle_info({:notification_deleted, %{notification_id: id}}, socket) do
    {:noreply, socket |> remove_notification(id) |> refresh_notification_metrics()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col overflow-hidden bg-[#050912] text-gray-100">
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        show_game_nav={true}
        active_tab={nil}
        notifications={@topbar_notifications}
        notifications_unread_count={@topbar_notifications_unread_count}
        show_notifications_menu={@show_notifications_menu}
      />

      <main class="flex-1 overflow-y-auto bg-[radial-gradient(circle_at_16%_12%,#12385f_0%,#071426_28%,#050912_55%,#03060d_100%)] p-3 md:p-5">
        <div class="mx-auto max-w-[1500px]">
          <section class="relative mb-4 overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#071325]/70 shadow-[0_18px_60px_rgba(8,145,178,0.2)]">
            <div class="absolute inset-0 bg-[linear-gradient(115deg,rgba(56,189,248,0.12),transparent_35%,rgba(34,197,94,0.08)_62%,transparent_78%)]" />
            <div class="relative flex flex-wrap items-end justify-between gap-4 px-4 py-4 md:px-5">
              <div>
                <p class="text-[10px] uppercase tracking-[0.22em] text-cyan-300/80">
                  {gettext("Command Relay")}
                </p>
                <h1 class="mt-1 text-xl font-bold text-white md:text-2xl">
                  {gettext("Notifications")}
                </h1>
                <p class="mt-1 text-xs text-cyan-100/80 md:text-sm">
                  {gettext("Battle reports and strategic system alerts are stored here.")}
                </p>
              </div>

              <div class="grid grid-cols-2 gap-2 text-right md:grid-cols-4">
                <.metric_card
                  label={gettext("Combat")}
                  value={@notification_metrics.combat}
                  locale={current_locale(@current_user)}
                  tone="cyan"
                />
                <.metric_card
                  label={gettext("Espionage")}
                  value={@notification_metrics.espionage}
                  locale={current_locale(@current_user)}
                  tone="emerald"
                />
                <.metric_card
                  label={gettext("Construction")}
                  value={@notification_metrics.construction}
                  locale={current_locale(@current_user)}
                  tone="amber"
                />
                <.metric_card
                  label={gettext("Universe")}
                  value={@notification_metrics.universe}
                  locale={current_locale(@current_user)}
                  tone="indigo"
                />
              </div>
            </div>
          </section>

          <section
            class="flex min-w-0 flex-row items-start gap-4"
            style="display: flex; flex-direction: row; align-items: flex-start; gap: 1rem;"
          >
            <aside
              class="min-w-0 overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#0a1528]/95 shadow-[0_18px_44px_rgba(2,8,22,0.62)]"
              style="flex: 0 0 380px; width: 380px;"
            >
              <div class="border-b border-cyan-500/15 bg-[linear-gradient(170deg,rgba(8,145,178,0.22),rgba(8,145,178,0.03))] px-4 py-3">
                <h2 class="text-lg font-bold text-white">{gettext("Recent Notifications")}</h2>
                <p class="mt-1 text-xs text-cyan-100/80">
                  {gettext("%{total} total alerts",
                    total: format_number(@notification_metrics.total, current_locale(@current_user))
                  )}
                </p>
              </div>

              <div class="max-h-[calc(100vh-15rem)] overflow-y-auto p-3 lg:min-h-[36rem]">
                <%= if @notifications == [] do %>
                  <div class="rounded-xl border border-dashed border-cyan-600/30 bg-[#060d18]/70 p-4 text-sm text-gray-400">
                    {gettext("No notifications yet.")}
                  </div>
                <% else %>
                  <div class="space-y-2">
                    <%= for notification <- @notifications do %>
                      <article class={[
                        "rounded-xl border px-3 py-2.5 transition",
                        if(@selected_notification && @selected_notification.id == notification.id,
                          do: "border-cyan-400/65 bg-cyan-900/35",
                          else: "border-cyan-500/20 bg-[#050e1c]/80 hover:border-cyan-400/45"
                        )
                      ]}>
                        <div class="flex items-start gap-2">
                          <.link
                            navigate={~p"/notifications/#{notification.id}"}
                            class="min-w-0 flex-1"
                          >
                            <div class="flex items-start justify-between gap-2">
                              <p class="truncate text-sm font-semibold text-white">
                                {notification_title(notification, gettext("Battle Report"))}
                              </p>
                              <span
                                :if={is_nil(notification.read_at)}
                                class="mt-1 h-2 w-2 shrink-0 rounded-full bg-cyan-300"
                              />
                            </div>
                            <p class="mt-1 line-clamp-2 text-xs text-gray-300">
                              {notification_summary(notification, current_locale(@current_user))}
                            </p>
                            <p class="mt-2 text-[11px] text-gray-500">
                              {notification_time(notification.inserted_at)}
                            </p>
                          </.link>
                          <button
                            type="button"
                            phx-click="delete_notification"
                            phx-value-id={notification.id}
                            class="mt-0.5 h-7 w-7 shrink-0 rounded-lg border border-red-500/30 bg-red-950/30 text-xs font-bold text-red-200 transition hover:border-red-400/60 hover:bg-red-900/45"
                            title={gettext("Delete notification")}
                          >
                            X
                          </button>
                        </div>
                      </article>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </aside>

            <article
              class="min-h-[36rem] min-w-0 rounded-2xl border border-cyan-500/25 bg-[#0a1528]/95 p-4 shadow-[0_18px_44px_rgba(2,8,22,0.62)] md:p-5"
              style="flex: 1 1 auto;"
            >
              <%= if @selected_notification do %>
                <.notification_detail
                  notification={@selected_notification}
                  locale={current_locale(@current_user)}
                  won_label={gettext("Victory")}
                  lost_label={gettext("Defeat")}
                  draw_label={gettext("Draw")}
                />
              <% else %>
                <div class="flex h-full min-h-80 items-center justify-center rounded-xl border border-dashed border-cyan-600/30 bg-[#060d18]/70 p-6 text-center text-gray-400">
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

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :locale, :string, required: true
  attr :tone, :string, default: "cyan"

  defp metric_card(assigns) do
    assigns = assign(assigns, :value_label, format_number(assigns.value, assigns.locale))

    ~H"""
    <div class={[
      "rounded-lg border bg-[#04101d]/80 px-3 py-2",
      metric_tone_class(@tone)
    ]}>
      <p class="text-[10px] uppercase tracking-wide text-gray-500">{@label}</p>
      <p class="text-lg font-bold text-cyan-200">{@value_label}</p>
    </div>
    """
  end

  attr :notification, :map, required: true
  attr :locale, :string, required: true
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

    attacker_units = payload_get(payload, "attacker_units", [])
    defender_units = payload_get(payload, "defender_units", [])

    assigns =
      assigns
      |> assign(:payload, payload)
      |> assign(:outcome_label, outcome_label)
      |> assign(:attacker_units, attacker_units)
      |> assign(
        :defender_ship_units,
        Enum.filter(defender_units, &(payload_get(&1, "kind", "") == "ship"))
      )
      |> assign(
        :defender_defense_units,
        Enum.filter(defender_units, &(payload_get(&1, "kind", "") == "defense"))
      )
      |> assign(:round_summaries, payload_get(payload, "round_summaries", []))
      |> assign(:looted, payload_get(payload, "looted_resources", %{}))
      |> assign(:attacker_cost, payload_get(payload, "attacker_total_cost", %{}))
      |> assign(:defender_cost, payload_get(payload, "defender_total_cost", %{}))

    ~H"""
    <div class="space-y-4">
      <header class="rounded-xl border border-cyan-500/25 bg-[#051021]/75 p-4">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p class="text-[10px] uppercase tracking-[0.18em] text-cyan-300/80">
              {gettext("Battle Report")}
            </p>
            <h2 class="mt-1 text-xl font-bold text-white">
              {notification_title(@notification, gettext("Battle Report"))}
            </h2>
          </div>
          <span class={outcome_badge_class(payload_get(@payload, "outcome_for_recipient", "draw"))}>
            {@outcome_label}
          </span>
        </div>

        <div class="mt-4 grid gap-3 text-sm md:grid-cols-4">
          <.detail_stat
            label={gettext("Origin")}
            value={payload_get(@payload, "origin_planet_name", "-")}
          />
          <.detail_stat
            label={gettext("Target")}
            value={payload_get(@payload, "target_planet_name", "-")}
          />
          <.detail_stat
            label={gettext("Rounds")}
            value={format_number(payload_get(@payload, "rounds", 0), @locale)}
          />
          <.detail_stat
            label={gettext("Mission")}
            value={"#" <> to_string(payload_get(@payload, "mission_id", "-"))}
          />
        </div>
      </header>

      <div class="grid gap-3 md:grid-cols-3">
        <.resource_panel title={gettext("Looted Resources")} resources={@looted} locale={@locale} />
        <.resource_panel
          title={gettext("Attacker Loss Cost")}
          resources={@attacker_cost}
          locale={@locale}
        />
        <.resource_panel
          title={gettext("Defender Loss Cost")}
          resources={@defender_cost}
          locale={@locale}
        />
      </div>

      <div class="grid gap-3 2xl:grid-cols-3">
        <.unit_table
          title={gettext("Attacker Fleet")}
          rows={@attacker_units}
          locale={@locale}
          empty_label={gettext("No attacker units were recorded.")}
        />
        <.unit_table
          title={gettext("Defender Fleet")}
          rows={@defender_ship_units}
          locale={@locale}
          empty_label={gettext("No defending fleet was present.")}
        />
        <.unit_table
          title={gettext("Planetary Defenses")}
          rows={@defender_defense_units}
          locale={@locale}
          empty_label={gettext("No planetary defenses were present.")}
        />
      </div>

      <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85">
        <div class="border-b border-cyan-500/15 px-4 py-3">
          <h3 class="text-sm font-semibold uppercase tracking-[0.14em] text-cyan-300">
            {gettext("Round Summary")}
          </h3>
        </div>
        <div class="space-y-3 p-3">
          <%= if @round_summaries == [] do %>
            <p class="rounded-lg border border-dashed border-cyan-600/30 bg-[#050d18]/80 p-3 text-sm text-gray-500">
              {gettext("No round details were recorded.")}
            </p>
          <% else %>
            <%= for round <- @round_summaries do %>
              <.round_summary round={round} locale={@locale} />
            <% end %>
          <% end %>
        </div>
      </section>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail_stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-cyan-500/20 bg-[#04101d]/80 px-3 py-2">
      <p class="text-[10px] uppercase tracking-wide text-gray-500">{@label}</p>
      <p class="mt-1 truncate font-semibold text-cyan-100">{@value}</p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :resources, :map, required: true
  attr :locale, :string, required: true

  defp resource_panel(assigns) do
    ~H"""
    <section class="rounded-xl border border-cyan-500/20 bg-[#060f1d]/85 p-3 text-sm">
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{@title}</h3>
      <div class="mt-2 grid grid-cols-2 gap-2 text-gray-200">
        <%= for {label, key} <- resource_labels() do %>
          <div class="rounded-lg border border-cyan-500/10 bg-[#040b15]/80 px-2 py-1.5">
            <p class="text-[10px] uppercase tracking-wide text-gray-500">{label}</p>
            <p class="font-semibold text-white">
              {format_number(resource_value(@resources, key), @locale)}
            </p>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :locale, :string, required: true
  attr :empty_label, :string, required: true

  defp unit_table(assigns) do
    ~H"""
    <section class="overflow-hidden rounded-xl border border-cyan-500/20 bg-[#060f1d]/85">
      <div class="border-b border-cyan-500/15 px-3 py-2">
        <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">{@title}</h3>
      </div>

      <%= if @rows == [] do %>
        <p class="p-3 text-sm text-gray-500">{@empty_label}</p>
      <% else %>
        <div class="min-w-full overflow-x-auto">
          <table class="w-full text-left text-xs">
            <thead class="bg-[#04101d]/80 text-[10px] uppercase tracking-wide text-gray-500">
              <tr>
                <th class="px-3 py-2">{gettext("Unit")}</th>
                <th class="px-2 py-2 text-right">{gettext("Before")}</th>
                <th class="px-2 py-2 text-right">{gettext("After")}</th>
                <th class="px-3 py-2 text-right">{gettext("Lost")}</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-cyan-500/10">
              <%= for row <- @rows do %>
                <tr class="text-gray-200">
                  <td class="px-3 py-2">
                    <div class="flex items-center gap-2">
                      <img
                        src={payload_get(row, "icon_path", "/images/ships/ship-a.svg")}
                        alt=""
                        class="h-8 w-8 rounded border border-cyan-500/20 bg-[#020817] object-cover"
                      />
                      <div class="min-w-0">
                        <p class="truncate font-semibold text-white">
                          {payload_get(row, "name", "-")}
                        </p>
                        <p class="text-[10px] uppercase tracking-wide text-gray-500">
                          {payload_get(row, "class", "-")}
                        </p>
                      </div>
                    </div>
                  </td>
                  <td class="px-2 py-2 text-right font-semibold text-cyan-100">
                    {format_number(payload_get(row, "before", 0), @locale)}
                  </td>
                  <td class="px-2 py-2 text-right font-semibold text-emerald-200">
                    {format_number(payload_get(row, "after", 0), @locale)}
                  </td>
                  <td class="px-3 py-2 text-right font-semibold text-red-200">
                    {format_number(payload_get(row, "lost", 0), @locale)}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </section>
    """
  end

  attr :round, :map, required: true
  attr :locale, :string, required: true

  defp round_summary(assigns) do
    ~H"""
    <article class="rounded-xl border border-cyan-500/20 bg-[#050d18]/80 p-3">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h4 class="text-sm font-semibold text-white">
          {gettext("Round %{round}", round: payload_get(@round, "round", 0))}
        </h4>
        <span
          :if={payload_get(@round, "no_defenders", false)}
          class="rounded-full border border-emerald-500/30 bg-emerald-950/40 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-200"
        >
          {gettext("No defenders")}
        </span>
      </div>

      <div class="mt-3 grid gap-2 md:grid-cols-2">
        <div class="rounded-lg border border-cyan-500/10 bg-[#04101d]/80 p-2">
          <p class="text-[10px] uppercase tracking-wide text-gray-500">
            {gettext("Attacker firepower")}
          </p>
          <p class="mt-1 text-base font-bold text-cyan-100">
            {format_number(payload_get(@round, "attacker_power", 0), @locale)}
          </p>
          <.round_losses
            rows={payload_get(@round, "attacker_losses", [])}
            locale={@locale}
            empty_label={gettext("No attacker losses")}
          />
        </div>

        <div class="rounded-lg border border-cyan-500/10 bg-[#04101d]/80 p-2">
          <p class="text-[10px] uppercase tracking-wide text-gray-500">
            {gettext("Defender firepower")}
          </p>
          <p class="mt-1 text-base font-bold text-cyan-100">
            {format_number(payload_get(@round, "defender_power", 0), @locale)}
          </p>
          <.round_losses
            rows={payload_get(@round, "defender_losses", [])}
            locale={@locale}
            empty_label={gettext("No defender losses")}
          />
        </div>
      </div>
    </article>
    """
  end

  attr :rows, :list, required: true
  attr :locale, :string, required: true
  attr :empty_label, :string, required: true

  defp round_losses(assigns) do
    ~H"""
    <div class="mt-2 border-t border-cyan-500/10 pt-2">
      <%= if @rows == [] do %>
        <p class="text-xs text-gray-500">{@empty_label}</p>
      <% else %>
        <ul class="space-y-1 text-xs text-gray-300">
          <%= for row <- @rows do %>
            <li class="flex items-center justify-between gap-2">
              <span class="truncate">
                {payload_get(row, "name", payload_get(row, "unit_type", "-"))}
              </span>
              <span class="font-semibold text-red-200">
                -{format_number(payload_get(row, "lost", 0), @locale)}
              </span>
            </li>
          <% end %>
        </ul>
      <% end %>
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

  defp remove_notification(socket, id) do
    notifications = Enum.reject(socket.assigns.notifications, &(&1.id == id))

    selected =
      case socket.assigns.selected_notification do
        %{id: ^id} -> List.first(notifications)
        current -> current
      end

    socket
    |> assign(:notifications, notifications)
    |> assign(:selected_notification, selected)
  end

  defp refresh_notification_metrics(socket) do
    assign(
      socket,
      :notification_metrics,
      Notifications.notification_metrics_for_user(socket.assigns.current_user.id)
    )
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

  defp payload_get(_payload, _key, default), do: default

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

  defp notification_summary(notification, locale) do
    case notification.type do
      "battle_report" ->
        payload = notification.payload || %{}
        rounds = payload_get(payload, "rounds", 0)
        loot = payload_get(payload, "looted_resources", %{})

        gettext("%{rounds} rounds resolved. Loot: %{loot}.",
          rounds: format_number(rounds, locale),
          loot: resource_line(loot, locale)
        )

      _ ->
        notification.summary
    end
  end

  defp resource_line(resources, locale) when is_map(resources) do
    gettext("RM %{raw} / MC %{chips} / H2 %{hydro}",
      raw: format_number(resource_value(resources, "raw_materials"), locale),
      chips: format_number(resource_value(resources, "microchips"), locale),
      hydro: format_number(resource_value(resources, "hydrogen"), locale)
    )
  end

  defp notification_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  defp notification_time(_), do: "-"

  defp resource_labels do
    [
      {gettext("Raw"), "raw_materials"},
      {gettext("Microchips"), "microchips"},
      {gettext("Hydrogen"), "hydrogen"},
      {gettext("Food"), "food"},
      {gettext("Credits"), "credits"}
    ]
  end

  defp resource_value(resources, key) when is_map(resources) and key in @resource_fields do
    payload_get(resources, key, 0)
  end

  defp resource_value(_resources, _key), do: 0

  defp current_locale(%{locale: locale}) when locale in ["en", "es", "fr"], do: locale
  defp current_locale(_user), do: "en"

  defp format_number(value, locale) do
    number =
      case value do
        value when is_integer(value) -> value
        value when is_float(value) -> trunc(value)
        value when is_binary(value) -> parse_int(value)
        _ -> 0
      end

    separator =
      case locale do
        "es" -> "."
        "fr" -> " "
        _ -> ","
      end

    sign = if number < 0, do: "-", else: ""

    digits =
      number
      |> abs()
      |> Integer.to_string()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(fn chunk -> chunk |> Enum.reverse() |> Enum.join() end)
      |> Enum.reverse()
      |> Enum.join(separator)

    sign <> digits
  end

  defp parse_int(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      _ -> 0
    end
  end

  defp metric_tone_class("emerald"), do: "border-emerald-500/30"
  defp metric_tone_class("amber"), do: "border-amber-500/30"
  defp metric_tone_class("indigo"), do: "border-indigo-500/30"
  defp metric_tone_class(_), do: "border-cyan-500/30"

  defp outcome_badge_class("victory"),
    do:
      "rounded-full border border-emerald-500/40 bg-emerald-950/45 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-emerald-200"

  defp outcome_badge_class("defeat"),
    do:
      "rounded-full border border-red-500/40 bg-red-950/45 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-red-200"

  defp outcome_badge_class(_),
    do:
      "rounded-full border border-amber-500/40 bg-amber-950/45 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-amber-200"
end
