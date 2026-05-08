defmodule NexusDownfallWeb.PlanetsListLive do
  @moduledoc "Planets list view — browse all your planets with filters and overview cards."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Fleets
  alias NexusDownfall.Repo
  import Ecto.Query

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    premium_access = premium_access?(socket.assigns.current_user)

    planets = Fleets.list_planets_for_user(user_id)
    planets_with_data = load_planets_with_data(planets, premium_access)

    {:ok,
     socket
     |> assign(:premium_access, premium_access)
     |> assign(:planets, planets_with_data)
     |> assign(:filter_name, "")
     |> assign(:filter_has_construction, false)
     |> assign(:sort_by, "name")
     |> assign(:show_user_menu, false)}
  end

  def render(assigns) do
    assigns = assign_filtered_planets(assigns)

    ~H"""
    <div class="flex min-h-screen flex-col overflow-hidden bg-[#050912] font-sans select-none">
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        active_tab="cities"
      />

      <main class="flex-1 overflow-y-auto bg-[radial-gradient(circle_at_16%_12%,#12385f_0%,#071426_28%,#050912_55%,#03060d_100%)] p-3 md:p-5">
        <div class="mx-auto max-w-[1600px]">
          <!-- ══════ HEADER ══════ -->
          <section class="relative mb-6 overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#071325]/70 shadow-[0_18px_60px_rgba(8,145,178,0.2)]">
            <div class="absolute inset-0 bg-[linear-gradient(115deg,rgba(56,189,248,0.12),transparent_35%,rgba(34,197,94,0.08)_62%,transparent_78%)]" />
            <div class="relative flex flex-wrap items-end justify-between gap-4 px-4 py-4 md:px-5">
              <div>
                <p class="text-[10px] uppercase tracking-[0.22em] text-cyan-300/80"><%= gettext("Planetary Management") %></p>
                <h1 class="mt-1 text-xl font-bold text-white md:text-2xl"><%= gettext("Your Worlds") %></h1>
                <p class="mt-1 text-xs text-cyan-100/80 md:text-sm">
                  <%= gettext("Monitor your planets, view resources and active constructions.") %>
                </p>
              </div>

              <div class="grid grid-cols-2 gap-2 text-right md:grid-cols-3">
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Planets") %></p>
                  <p class="text-lg font-bold text-cyan-200"><%= length(@planets) %></p>
                </div>
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Building") %></p>
                  <p class="text-lg font-bold text-amber-300">
                    <%= Enum.count(@planets, &(&1.any_constructing == true)) %>
                  </p>
                </div>
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Population") %></p>
                  <p class="text-lg font-bold text-emerald-300">
                    <%= @planets |> Enum.map(& &1.population) |> Enum.sum() |> format_number() %>
                  </p>
                </div>
              </div>
            </div>
          </section>

          <!-- ══════ FILTERS (PREMIUM ONLY) ══════ -->
          <%= if @premium_access do %>
            <section class="mb-6 overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#071325]/70 p-4">
              <h3 class="mb-3 text-sm font-bold uppercase text-cyan-200 tracking-wide">
                <%= gettext("Advanced Filters") %>
              </h3>

              <div class="grid gap-3 md:grid-cols-4">
                <div>
                  <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500">
                    <%= gettext("Planet Name") %>
                  </label>
                  <input
                    type="text"
                    placeholder={gettext("Search...")}
                    value={@filter_name}
                    phx-change="update_filter_name"
                    class="w-full rounded-lg border border-cyan-500/20 bg-[#060d18] px-3 py-2 text-sm text-white placeholder-gray-500 focus:border-cyan-400 focus:outline-none"
                  />
                </div>

                <div>
                  <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500">
                    <%= gettext("Status") %>
                  </label>
                  <select
                    phx-change="update_filter_construction"
                    class="w-full rounded-lg border border-cyan-500/20 bg-[#060d18] px-3 py-2 text-sm text-white focus:border-cyan-400 focus:outline-none"
                  >
                    <option value="all"><%= gettext("All") %></option>
                    <option value="building" selected={@filter_has_construction}>
                      <%= gettext("Building") %>
                    </option>
                    <option value="idle"><%= gettext("Idle") %></option>
                  </select>
                </div>

                <div>
                  <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500">
                    <%= gettext("Sort By") %>
                  </label>
                  <select
                    phx-change="update_sort_by"
                    class="w-full rounded-lg border border-cyan-500/20 bg-[#060d18] px-3 py-2 text-sm text-white focus:border-cyan-400 focus:outline-none"
                  >
                    <option value="name"><%= gettext("Name") %></option>
                    <option value="population"><%= gettext("Population") %></option>
                    <option value="resources"><%= gettext("Total Resources") %></option>
                  </select>
                </div>

                <div class="flex items-end">
                  <button
                    phx-click="reset_filters"
                    class="w-full rounded-lg bg-gray-700/50 px-3 py-2 text-sm font-semibold text-gray-300 transition hover:bg-gray-700"
                  >
                    <%= gettext("Reset") %>
                  </button>
                </div>
              </div>
            </section>
          <% end %>

          <!-- ══════ PLANETS GRID ══════ -->
          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            <%= for planet <- @filtered_planets do %>
              <.planet_card planet={planet} premium_access={@premium_access} />
            <% end %>

            <%= if Enum.empty?(@filtered_planets) do %>
              <div class="col-span-full flex items-center justify-center rounded-xl border border-cyan-500/20 bg-[#060d18]/50 py-12">
                <div class="text-center">
                  <p class="text-sm text-gray-400"><%= gettext("No planets match your filters.") %></p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def handle_event("update_filter_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, :filter_name, name)}
  end

  def handle_event("update_filter_construction", %{"value" => filter}, socket) do
    {:noreply, assign(socket, :filter_has_construction, filter == "building")}
  end

  def handle_event("update_sort_by", %{"value" => sort}, socket) do
    {:noreply, assign(socket, :sort_by, sort)}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filter_name, "")
     |> assign(:filter_has_construction, false)
     |> assign(:sort_by, "name")}
  end

  defp planet_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/planets/#{@planet.id}"}
      class="group relative overflow-hidden rounded-2xl border border-cyan-500/25 bg-gradient-to-b from-[#0a1a2e] to-[#050912] shadow-lg transition hover:border-cyan-400/50 hover:shadow-[0_8px_32px_rgba(34,211,238,0.2)]"
    >
      <div class="relative aspect-video overflow-hidden bg-[#040810]">
        <img
          src={planet_image_path(@planet.planet_image_id)}
          alt={@planet.name}
          class="h-full w-full object-cover transition group-hover:scale-105"
        />
        <div class="absolute inset-0 bg-gradient-to-t from-[#050912] via-transparent to-transparent" />
      </div>

      <div class="relative p-4">
        <div class="mb-3">
          <h3 class="text-base font-bold text-white group-hover:text-cyan-200">
            <%= @planet.name %>
          </h3>
          <p class="mt-1 text-[11px] text-gray-400">
            <%= gettext("System") %>: [<%= @planet.galaxy_number %>:<%= @planet.system_name %>:<%= @planet.orbit_position %>:<%= @planet.region %>]
          </p>
        </div>

        <div class="grid grid-cols-2 gap-2 mb-3 text-[11px]">
          <div class="rounded bg-[#060d18]/60 px-2 py-1.5">
            <p class="text-gray-500"><%= gettext("Population") %></p>
            <p class="font-bold text-emerald-300"><%= format_number(@planet.population) %></p>
          </div>
          <div class="rounded bg-[#060d18]/60 px-2 py-1.5">
            <p class="text-gray-500"><%= gettext("Status") %></p>
            <p class={[
              "font-bold",
              if(@planet.any_constructing, do: "text-amber-300", else: "text-green-300")
            ]}>
              <%= if @planet.any_constructing, do: gettext("Building"), else: gettext("Idle") %>
            </p>
          </div>
        </div>

        <%= if @planet.any_constructing and @planet.active_construction_label do %>
          <p class="mb-3 text-[11px] text-amber-200">
            <span class="font-semibold"><%= gettext("Building") %>:</span> <%= @planet.active_construction_label %>
          </p>
        <% end %>

        <%= if @premium_access do %>
          <div class="mb-2 border-t border-cyan-500/10 pt-2">
            <div class="grid grid-cols-3 gap-1 text-[10px]">
              <div class="text-center">
                <p class="text-gray-500"><%= gettext("Raw") %></p>
                <p class="font-semibold text-blue-300"><%= format_number(@planet.raw_materials, 0) %></p>
              </div>
              <div class="text-center">
                <p class="text-gray-500"><%= gettext("Chips") %></p>
                <p class="font-semibold text-purple-300"><%= format_number(@planet.microchips, 0) %></p>
              </div>
              <div class="text-center">
                <p class="text-gray-500"><%= gettext("H₂") %></p>
                <p class="font-semibold text-cyan-300"><%= format_number(@planet.hydrogen, 0) %></p>
              </div>
            </div>
          </div>

          <%= if @planet.fleet_count > 0 do %>
            <p class="text-[10px] text-gray-400">
              <span class="font-semibold text-yellow-300"><%= @planet.fleet_count %></span>
              <%= gettext("fleets stationed") %>
            </p>
          <% end %>
        <% end %>

        <div class="absolute top-2 right-2 rounded-lg bg-cyan-500/20 px-2 py-1 text-[10px] font-semibold text-cyan-200 opacity-0 transition group-hover:opacity-100">
          <%= gettext("View Details") %>
        </div>
      </div>
    </.link>
    """
  end

  defp assign_filtered_planets(assigns) do
    filtered =
      assigns.planets
      |> filter_by_name(assigns.filter_name)
      |> filter_by_construction(assigns.filter_has_construction, assigns.premium_access)
      |> sort_planets(assigns.sort_by)

    assign(assigns, :filtered_planets, filtered)
  end

  defp filter_by_name(planets, ""), do: planets

  defp filter_by_name(planets, name) do
    name_lower = String.downcase(name)
    Enum.filter(planets, &(String.downcase(&1.name) =~ name_lower))
  end

  defp filter_by_construction(planets, false, _premium), do: planets

  defp filter_by_construction(planets, true, true) do
    Enum.filter(planets, &(&1.any_constructing == true))
  end

  defp filter_by_construction(planets, _filter, false), do: planets

  defp sort_planets(planets, "name") do
    Enum.sort_by(planets, &String.downcase(&1.name))
  end

  defp sort_planets(planets, "population") do
    Enum.sort_by(planets, &(-&1.population))
  end

  defp sort_planets(planets, "resources") do
    Enum.sort_by(planets, fn p ->
      -(p.raw_materials + p.microchips + p.hydrogen + p.food + p.credits)
    end)
  end

  defp sort_planets(planets, _), do: planets

  defp load_planets_with_data(planets, premium_access) do
    planets_preloaded = Repo.preload(planets, [:buildings, solar_system: :galaxy])

    fleet_counts_by_planet =
      if premium_access do
        planet_ids = Enum.map(planets_preloaded, & &1.id)

        Repo.all(
          from f in Fleets.Fleet,
            where: f.home_planet_id in ^planet_ids,
            group_by: f.home_planet_id,
            select: {f.home_planet_id, count(f.id)}
        )
        |> Map.new()
      else
        %{}
      end

    planets_with_construction =
      Enum.map(planets_preloaded, fn planet ->
        active_building = Enum.find(planet.buildings, &(&1.construction_finish_at != nil))

        planet
        |> Map.put(:any_constructing, not is_nil(active_building))
        |> Map.put(:active_construction_label, active_construction_label(active_building))
        |> Map.put(:system_name, planet.solar_system.number)
        |> Map.put(:galaxy_number, planet.solar_system.galaxy.number)
      end)

    Enum.map(planets_with_construction, fn planet ->
      Map.put(planet, :fleet_count, Map.get(fleet_counts_by_planet, planet.id, 0))
    end)
  end

  defp planet_image_path(image_id) do
    "/images/Planets/#{image_id}.png"
  end

  defp format_number(num, digits \\ 1) when is_integer(num) do
    cond do
      num >= 1_000_000 -> Float.round(num / 1_000_000, digits) |> Kernel.<>("M")
      num >= 1_000 -> Float.round(num / 1_000, digits) |> Kernel.<>("K")
      true -> Integer.to_string(num)
    end
  end

  defp premium_access?(user) do
    cond do
      Map.get(user, :premium, false) -> true
      Map.get(user, :is_premium, false) -> true
      Map.get(user, :premium_active, false) -> true
      Map.get(user, :premium_subscription, false) -> true
      Map.get(user, :subscription_tier) in ["premium", "pro", "elite"] -> true
      true -> false
    end
  end

  defp active_construction_label(nil), do: nil

  defp active_construction_label(building) do
    building.type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
