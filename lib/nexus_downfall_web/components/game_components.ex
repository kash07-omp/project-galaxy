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
  attr :active_tab, :any, default: nil
  attr :galaxy_id, :any, default: nil
  attr :planet_id, :any, default: nil
  attr :context_label, :string, default: nil

  @doc "Renders the universal game navigation topbar."
  def topbar(assigns) do
    ~H"""
    <nav class="flex items-center justify-between bg-gray-900/95 border-b border-gray-800 px-3 h-10 shrink-0 z-30 backdrop-blur select-none">
      <%!-- Logo --%>
      <.link navigate={~p"/dashboard"} class="flex items-center gap-1.5 shrink-0">
        <span class="text-cyan-400 text-base">⬡</span>
        <span class="text-white font-bold tracking-widest text-xs uppercase">Nexus</span>
        <span class="text-cyan-400 font-bold text-xs">:</span>
        <span class="text-cyan-300 font-bold tracking-widest text-xs uppercase">Downfall</span>
      </.link>

      <%!-- Nav tabs --%>
      <div class="flex items-center gap-0.5 text-[11px] font-medium overflow-x-auto px-2">
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
          <.game_nav_tab href={~p"/planets"} label={gettext("Cities")} active={@active_tab == "cities"} />
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
        <span class="text-gray-400 text-xs hidden sm:block">{topbar_player_name(@current_user)}</span>
        <button
          phx-click="toggle_user_menu"
          class="w-7 h-7 rounded-full bg-cyan-800 border-2 border-cyan-600 flex items-center justify-center text-xs font-bold text-white uppercase hover:bg-cyan-700 transition"
        >
          {String.first(topbar_player_name(@current_user))}
        </button>
        <%= if @show_user_menu do %>
          <div class="fixed inset-0 z-40" phx-click="toggle_user_menu" />
          <div class="absolute top-9 right-0 z-50 w-44 bg-gray-900 border border-gray-700 rounded-xl shadow-2xl overflow-hidden">
            <.link
              navigate={~p"/users/settings"}
              phx-click="toggle_user_menu"
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
    user.email |> String.split("@") |> hd()
  end
end
