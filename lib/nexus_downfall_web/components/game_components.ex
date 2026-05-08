defmodule NexusDownfallWeb.GameComponents do
  @moduledoc """
  Shared game UI components used across all LiveViews.

  Includes the universal topbar with logo, nav tabs, and user menu.
  """

  use Phoenix.Component
  use NexusDownfallWeb, :verified_routes
  use Gettext, backend: NexusDownfallWeb.Gettext

  # ---------------------------------------------------------------------------
  # Universal topbar
  # ---------------------------------------------------------------------------

  attr :current_user, :map, required: true
  attr :show_user_menu, :boolean, default: false
  attr :show_game_nav, :boolean, default: true
  attr :active_tab, :any, default: nil
  attr :galaxy_id, :any, default: nil
  attr :planet_id, :any, default: nil
  attr :context_label, :string, default: nil
  attr :logo_path, :string, default: "/dashboard"
  attr :notifications, :list, default: []
  attr :notifications_unread_count, :integer, default: 0
  attr :show_notifications_menu, :boolean, default: false

  @doc "Renders the universal game navigation topbar."
  def topbar(assigns) do
    ~H"""
    <nav class="flex items-center justify-between bg-gray-900/95 border-b border-gray-800 px-3 h-10 shrink-0 z-30 backdrop-blur select-none">
      <%!-- Logo --%>
      <.link navigate={@logo_path} class="flex items-center gap-1.5 shrink-0">
        <span class="text-cyan-400 text-base">⬡</span>
        <span class="text-white font-bold tracking-widest text-xs uppercase">Nexus</span>
        <span class="text-cyan-400 font-bold text-xs">:</span>
        <span class="text-cyan-300 font-bold tracking-widest text-xs uppercase">Downfall</span>
      </.link>

      <%!-- Nav tabs --%>
      <div
        :if={@show_game_nav}
        class="flex items-center gap-0.5 text-[11px] font-medium overflow-x-auto px-2"
      >
        <%= if @galaxy_id do %>
          <.game_nav_tab
            href={~p"/galaxies/#{@galaxy_id}"}
            label={gettext("Galaxy")}
            active={@active_tab == "galaxy"}
          />
        <% else %>
          <.game_nav_tab href="#" label={gettext("Galaxy")} active={@active_tab == "galaxy"} />
        <% end %>

        <%= if @planet_id do %>
          <.game_nav_tab
            href={~p"/planets/#{@planet_id}"}
            label={gettext("Cities")}
            active={@active_tab == "cities"}
          />
        <% else %>
          <.game_nav_tab
            href={~p"/planets"}
            label={gettext("Cities")}
            active={@active_tab == "cities"}
          />
        <% end %>
        <.game_nav_tab href="#" label={gettext("Research")} active={false} />
        <.game_nav_tab href="#" label={gettext("Laws")} active={false} />
        <.game_nav_tab href="#" label={gettext("Trade")} active={false} />
        <.game_nav_tab href="#" label={gettext("Diplomacy")} active={false} />
        <.game_nav_tab href="#" label={gettext("Clans")} active={false} />
        <.game_nav_tab href="#" label={gettext("Cards")} active={false} />
        <.game_nav_tab href={~p"/fleet"} label={gettext("Fleet")} active={@active_tab == "fleet"} />
        <.game_nav_tab href="#" label={gettext("Ranking")} active={false} />
        <.game_nav_tab href="#" label={gettext("Store")} active={false} />
        <%= if @context_label do %>
          <span class="ml-2 px-2 py-0.5 rounded text-cyan-300 bg-cyan-900/40 border border-cyan-700/50 text-[10px] shrink-0">
            {@context_label}
          </span>
        <% end %>
      </div>
      <%!-- User menu --%>
      <div class="relative flex items-center gap-2 shrink-0">
        <div class="relative">
          <button
            phx-click="toggle_notifications_menu"
            class="relative h-7 w-7 rounded-full border border-cyan-700/70 bg-cyan-900/35 text-cyan-200 transition hover:bg-cyan-800/55"
            title={gettext("Notifications")}
          >
            🔔
            <span
              :if={@notifications_unread_count > 0}
              class="absolute -right-1 -top-1 min-w-4 rounded-full bg-emerald-400 px-1 text-[9px] font-bold leading-4 text-emerald-950"
            >
              {min(@notifications_unread_count, 99)}
            </span>
          </button>

          <%= if @show_notifications_menu do %>
            <div
              phx-click-away="close_notifications_menu"
              class="absolute top-9 right-0 z-50 w-80 max-w-[85vw] overflow-hidden rounded-xl border border-gray-700 bg-gray-900 shadow-2xl"
            >
              <div class="flex items-center justify-between border-b border-gray-800 px-3 py-2">
                <p class="text-xs font-semibold uppercase tracking-[0.14em] text-cyan-300">
                  {gettext("Notifications")}
                </p>
                <span class="text-[11px] text-gray-400">
                  {gettext("Unread")}: {@notifications_unread_count}
                </span>
              </div>

              <%= if @notifications == [] do %>
                <div class="px-3 py-4 text-xs text-gray-400">
                  {gettext("No notifications yet.")}
                </div>
              <% else %>
                <div class="max-h-96 overflow-y-auto py-1">
                  <.link
                    :for={notification <- @notifications}
                    navigate={~p"/notifications/#{notification.id}"}
                    class="block border-b border-gray-800/70 px-3 py-2 transition hover:bg-gray-800"
                  >
                    <p class="truncate text-sm font-semibold text-white">
                      {notification_title(notification)}
                    </p>
                    <p class="mt-0.5 truncate text-xs text-gray-300">
                      {notification_summary(notification)}
                    </p>
                    <p class="mt-1 text-[11px] text-gray-500">{notification_time(notification)}</p>
                  </.link>
                </div>
              <% end %>

              <.link
                navigate={~p"/notifications"}
                class="block border-t border-gray-800 px-3 py-2 text-center text-xs font-semibold text-cyan-300 transition hover:bg-gray-800"
              >
                {gettext("View all notifications")}
              </.link>
            </div>
          <% end %>
        </div>

        <span class="text-gray-400 text-xs hidden sm:block">{topbar_player_name(@current_user)}</span>
        <button
          phx-click="toggle_user_menu"
          class="w-7 h-7 rounded-full bg-cyan-800 border-2 border-cyan-600 flex items-center justify-center text-xs font-bold text-white uppercase hover:bg-cyan-700 transition"
        >
          {String.first(topbar_player_name(@current_user))}
        </button>
        <%= if @show_user_menu do %>
          <div
            phx-click-away="toggle_user_menu"
            class="absolute top-9 right-0 z-50 w-44 bg-gray-900 border border-gray-700 rounded-xl shadow-2xl overflow-hidden"
          >
            <.link
              navigate={~p"/users/settings"}
              class="flex items-center gap-2 px-4 py-2.5 text-sm text-gray-300 hover:bg-gray-800 hover:text-white transition"
            >
              ⚙️ {gettext("Settings")}
            </.link>
            <div class="border-t border-gray-800" />
            <.link
              href={~p"/users/log_out"}
              method="delete"
              class="flex items-center gap-2 px-4 py-2.5 text-sm text-red-400 hover:bg-gray-800 hover:text-red-300 transition"
            >
              🚪 {gettext("Sign out")}
            </.link>
          </div>
        <% end %>
      </div>
    </nav>
    """
  end

  # ---------------------------------------------------------------------------
  # Nav tab (inner component — not exported as public)
  # ---------------------------------------------------------------------------

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true

  defp game_nav_tab(assigns) do
    ~H"""
    <.link
      href={@href}
      class={[
        "px-2 py-1 rounded-sm transition-colors whitespace-nowrap",
        if(@active,
          do: "text-white bg-cyan-800/60 border-b-2 border-cyan-400",
          else: "text-gray-400 hover:text-gray-200 hover:bg-gray-800"
        )
      ]}
    >
      {@label}
    </.link>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp topbar_player_name(user) do
    cond do
      is_binary(user.account_name) and user.account_name != "" -> user.account_name
      true -> user.email |> String.split("@") |> hd()
    end
  end

  defp notification_title(%{type: "battle_report", payload: payload}) do
    outcome = payload_value(payload, "outcome_for_recipient", "draw")

    case outcome do
      "victory" -> gettext("Battle won")
      "defeat" -> gettext("Battle lost")
      _ -> gettext("Battle ended in draw")
    end
  end

  defp notification_title(%{title: title}) when is_binary(title) and title != "", do: title
  defp notification_title(_), do: gettext("Notification")

  defp notification_summary(%{type: "battle_report", payload: payload}) do
    rounds = payload_value(payload, "rounds", 0)
    gettext("%{rounds} rounds resolved.", rounds: rounds)
  end

  defp notification_summary(%{summary: summary}) when is_binary(summary) and summary != "", do: summary
  defp notification_summary(_), do: gettext("Open for details.")

  defp notification_time(%{inserted_at: %DateTime{} = inserted_at}) do
    Calendar.strftime(inserted_at, "%Y-%m-%d %H:%M")
  end

  defp notification_time(_), do: "-"

  defp payload_value(payload, key, default) when is_map(payload) do
    Map.get(payload, key, Map.get(payload, maybe_existing_atom(key), default))
  end

  defp payload_value(_payload, _key, default), do: default

  defp maybe_existing_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> nil
    end
  end

  defp maybe_existing_atom(_), do: nil
end
