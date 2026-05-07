defmodule NexusDownfallWeb.DashboardLive do
  @moduledoc "Authenticated dashboard — shows the player's active universes."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Accounts
  alias NexusDownfall.Planets

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-950 text-gray-100 font-sans">

      <!-- ══════ TOPBAR ══════ -->
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        active_tab={nil}
      />

      <main class="flex-1 p-6">
        <h1 class="text-xl font-bold text-cyan-400 tracking-widest uppercase mb-6">
          <%= gettext("Command Bridge") %>
        </h1>

        <section>
          <h2 class="text-lg font-semibold text-gray-300 mb-4"><%= gettext("Your Universes") %></h2>

          <%= if @memberships == [] do %>
            <div class="rounded-lg border border-gray-800 bg-gray-900 p-8 text-center">
              <p class="text-gray-500 mb-4"><%= gettext("You have not joined any universe yet.") %></p>
              <.link
                navigate={~p"/universes"}
                class="inline-block px-4 py-2 rounded bg-cyan-700 hover:bg-cyan-600 text-white text-sm font-medium"
              >
                <%= gettext("Browse Universes") %>
              </.link>
            </div>
          <% else %>
            <ul class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for uu <- @memberships do %>
                <li class="rounded-lg border border-gray-800 bg-gray-900 p-4 space-y-2">
                  <div class="flex items-center justify-between">
                    <p class="text-cyan-300 font-semibold">{uu.universe.name}</p>
                    <%= if first_planet = List.first(uu.planets) do %>
                      <.link
                        navigate={~p"/planets/#{first_planet.id}"}
                        class="px-2 py-0.5 rounded bg-cyan-800 hover:bg-cyan-700 text-xs text-white font-medium"
                      >
                        <%= gettext("View Planet") %>
                      </.link>
                    <% end %>
                  </div>
                  <p class="text-xs text-gray-500">
                    alias: <span class="text-gray-300">{uu.username}</span>
                  </p>
                  <p class="text-xs text-gray-500">
                    score: <span class="text-gray-300">{uu.score}</span>
                  </p>
                </li>
              <% end %>
            </ul>
          <% end %>
        </section>
      </main>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    memberships =
      socket.assigns.current_user.id
      |> Accounts.list_universe_memberships()
      |> Enum.map(fn uu ->
        planets = Planets.list_planets_for_user(uu.id)
        Map.put(uu, :planets, planets)
      end)

    {:ok,
     socket
     |> assign(:memberships, memberships)
     |> assign(:show_user_menu, false)}
  end

  def handle_event("toggle_user_menu", _, socket),
    do: {:noreply, update(socket, :show_user_menu, &(!&1))}
end
