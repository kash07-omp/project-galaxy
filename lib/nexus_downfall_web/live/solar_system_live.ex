defmodule NexusDownfallWeb.SolarSystemLive do
  @moduledoc """
  Solar system view — 3D-perspective canvas with stationary planets.

  Uses the `SolarSystem` JS hook to render planets on a canvas element.
  Clicking a planet fires `planet_selected` which shows an info panel.
  """

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Universe

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  def mount(%{"id" => system_id}, _session, socket) do
    system = Universe.get_system_with_planets!(system_id)
    galaxy = system.galaxy

    {:ok,
     socket
     |> assign(:system, system)
     |> assign(:galaxy, galaxy)
     |> assign(:planets, system.planets)
     |> assign(:planet_data, build_planet_data(system.planets, socket.assigns.current_user.id))
     |> assign(:selected_planet, nil)
     |> assign(:show_user_menu, false)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("planet_selected", %{"orbit" => orbit, "region" => region, "planet_id" => planet_id}, socket) do
    planet = Enum.find(socket.assigns.planets, fn p ->
      p.orbit_position == orbit and p.region == region
    end)

    {:noreply, assign(socket, :selected_planet, planet || %{orbit_position: orbit, region: region, id: planet_id})}
  end

  def handle_event("deselect", _, socket),
    do: {:noreply, assign(socket, :selected_planet, nil)}

  def handle_event("toggle_user_menu", _, socket),
    do: {:noreply, update(socket, :show_user_menu, &(!&1))}

  def handle_event("close_menu", _, socket),
    do: {:noreply, assign(socket, :show_user_menu, false)}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_planet_data(planets, current_user_id) do
    planets
    |> Enum.map(fn p ->
      universe_user = p.universe_user

      %{
        orbit: p.orbit_position,
        region: p.region,
        name: p.name,
        planet_id: p.id,
        slot_type: p.slot_type || "planet",
        planet_subtype: p.planet_subtype,
        occupied: universe_user != nil,
        is_own: universe_user != nil and universe_user.user_id == current_user_id,
        player: if(universe_user, do: universe_user.username, else: nil)
      }
    end)
    |> Jason.encode!()
  end

  defp planet_owner_name(%{universe_user: %{username: name}}) when is_binary(name), do: name
  defp planet_owner_name(_), do: nil

  defp own_planet?(planet, current_user_id) do
    match?(%{universe_user: %{user_id: ^current_user_id}}, planet)
  end

  defp slot_title(planet) do
    cond do
      Map.get(planet, :slot_type) == "asteroid_ring" ->
        gettext("Asteroid belt")

      Map.get(planet, :universe_user_id) != nil ->
        Map.get(planet, :name) || gettext("Colonised")

      true ->
        gettext("Empty slot")
    end
  end

  defp subtype_label(subtype) do
    case subtype do
      "rocky" -> gettext("Rocky")
      "gas_giant" -> gettext("Gas giant")
      "ice" -> gettext("Ice")
      "ocean" -> gettext("Ocean")
      "lava" -> gettext("Lava")
      "desert" -> gettext("Desert")
      _ -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-gray-950 font-sans overflow-hidden select-none">

      <!-- ══════ TOPBAR ══════ -->
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        active_tab="galaxy"
        galaxy_id={@galaxy.id}
        context_label={gettext("System %{number}", number: @system.number)}
      />

      <!-- ══════ MAIN CONTENT ══════ -->
      <main class="flex-1 overflow-hidden flex">

        <!-- PixiJS Canvas Area -->
        <div class="flex-1 relative overflow-hidden">
          <div
            id="solar-system-canvas-wrapper"
            class="w-full h-full"
            phx-hook="SolarSystem"
            data-planets={@planet_data}
            data-bg="/images/space_background_2.jpg"
            data-hyperlanes="4"
            data-label-your-planet={gettext("Your planet")}
            data-label-colonised={gettext("Colonised")}
            phx-update="ignore"
          >
            <div id="pixi-mount" class="w-full h-full" style="position:relative;z-index:1;"></div>
            <div
              id="nameplate-overlay"
              class="absolute inset-0 pointer-events-none"
              style="z-index:2;"
            ></div>
          </div>
        </div>

        <!-- ══════ SIDE PANEL ══════ -->
        <aside class="w-64 bg-gray-900/95 border-l border-gray-800 flex flex-col p-4 gap-4 shrink-0 overflow-y-auto">
          <h2 class="text-cyan-300 font-bold text-sm tracking-widest uppercase">
            <%= gettext("System") %> <%= @system.number %>
          </h2>

          <%= if @selected_planet do %>
            <% sp = @selected_planet %>
            <div class="bg-gray-800 border border-gray-700 rounded-lg p-3 flex flex-col gap-2">
              <p class="text-white text-xs font-semibold">
                <%= slot_title(sp) %>
              </p>
              <p class="text-gray-400 text-xs">
                <%= gettext("Orbit") %> <%= sp.orbit_position %> · <%= gettext("Region") %> <%= sp.region %>
              </p>
              <%= if sp.planet_subtype do %>
                <p class="text-gray-500 text-xs"><%= subtype_label(sp.planet_subtype) %></p>
              <% end %>

              <%= cond do %>
                <% own_planet?(sp, @current_user.id) -> %>
                  <p class="text-cyan-300 text-xs"><%= gettext("Your planet") %></p>
                  <.link
                    navigate={~p"/planets/#{sp.id}"}
                    class="mt-1 block text-center bg-cyan-700 hover:bg-cyan-600 text-white text-xs py-1.5 rounded transition"
                  >
                    <%= gettext("Go to Planet") %> →
                  </.link>

                <% planet_owner_name(sp) != nil -> %>
                  <p class="text-orange-300 text-xs">
                    👤 <%= planet_owner_name(sp) %>
                  </p>

                <% true -> %>
                  <p class="text-gray-500 text-xs italic"><%= gettext("Uninhabited") %></p>
              <% end %>

              <button
                phx-click="deselect"
                class="mt-1 text-gray-500 hover:text-gray-300 text-xs text-left transition"
              >
                <%= gettext("Close") %> ×
              </button>
            </div>
          <% else %>
            <p class="text-gray-500 text-xs italic"><%= gettext("Click a planet to view info.") %></p>
          <% end %>

          <!-- Planet list summary -->
          <div class="flex flex-col gap-1 mt-2">
            <p class="text-gray-500 text-[10px] uppercase tracking-widest mb-1"><%= gettext("Slots") %></p>
            <%= for p <- @planets do %>
              <% dot_color = cond do
                own_planet?(p, @current_user.id) -> "bg-cyan-400"
                p.universe_user_id != nil -> "bg-orange-400"
                p.slot_type == "asteroid_ring" -> "bg-yellow-700"
                true -> "bg-gray-600"
              end %>
              <div class="flex items-center gap-2 text-xs">
                <span class={"inline-block w-2 h-2 rounded-full #{dot_color}"}></span>
                <span class="text-gray-300 truncate">
                  <%= if p.universe_user_id do %>
                    <%= p.name %>
                  <% else %>
                    <%= if p.slot_type == "asteroid_ring", do: gettext("Belt"), else: gettext("Empty") %>
                  <% end %>
                </span>
                <span class="text-gray-600 ml-auto shrink-0"><%= p.orbit_position %></span>
              </div>
            <% end %>
          </div>

          <!-- Legend -->
          <div class="mt-auto flex flex-col gap-1 pt-4 border-t border-gray-800 text-[10px] text-gray-500">
            <div class="flex items-center gap-2"><span class="w-2 h-2 rounded-full bg-cyan-400 inline-block"></span> <%= gettext("Your planet") %></div>
            <div class="flex items-center gap-2"><span class="w-2 h-2 rounded-full bg-orange-400 inline-block"></span> <%= gettext("Colonised") %></div>
            <div class="flex items-center gap-2"><span class="w-2 h-2 rounded-full bg-yellow-700 inline-block"></span> <%= gettext("Asteroid belt") %></div>
            <div class="flex items-center gap-2"><span class="w-2 h-2 rounded-full bg-gray-600 inline-block"></span> <%= gettext("Empty") %></div>
          </div>
        </aside>
      </main>
    </div>
    """
  end
end
