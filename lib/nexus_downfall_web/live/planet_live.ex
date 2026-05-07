defmodule NexusDownfallWeb.PlanetLive do
  @moduledoc "Planetary management screen — Ikariam-style map view."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.ProductionEngine
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.SolarSystem

  @ui_tick_ms 1_000
  @db_persist_secs 60

  # {db_type, image_file, {left_pct, top_pct}}
  @building_layout [
    {"hydrogen_extractor", "hydrogen-mine.png",      {22, 12}},
    {"microchip_factory",  "microchip-factory.png",  {50, 18}},
    {"spaceport",          "spaceport.png",           {72, 16}},
    {"residential",        "residential-area.png",    {20, 43}},
    {"command_center",     "city-hall.png",           {46, 50}},
    {"mine_raw",           "raw-material-mine.png",   {64, 40}},
    {"farm",               "farmland.png",            {9,  62}},
    {"laboratory",         "research-center.png",     {58, 70}},
    {"power_plant",        "energy-generator.png",    {80, 54}},
    {"nuclear_reactor",    "nuclear-reactor.png",     {92, 70}},
    {"defense_center",     "defense-center.png",      {35, 82}},
    {"component_factory",  "microchip-factory.png",   {65, 80}}
  ]

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  def mount(%{"id" => planet_id}, _session, socket) do
    {:ok, buildings} = Planets.ensure_building_slots(planet_id)
    {:ok, planet} = Planets.apply_production_tick(Planets.get_planet!(planet_id))
    rates = ProductionEngine.calculate_rates(buildings)

    # Load galaxy_id for nav link
    system = Repo.get!(SolarSystem, planet.solar_system_id)
    galaxy_id = system.galaxy_id

    if connected?(socket), do: schedule_ui_tick()

    {:ok,
     socket
     |> assign(:planet, planet)
     |> assign(:buildings, buildings)
     |> assign(:rates, rates)
     |> assign(:display, resource_display(planet))
     |> assign(:last_persist, DateTime.utc_now())
     |> assign(:now, DateTime.utc_now())
     |> assign(:selected, nil)
     |> assign(:selected_tab, "info")
     |> assign(:show_user_menu, false)
     |> assign(:galaxy_id, galaxy_id)
     |> assign(:error, nil)}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    assigns =
      assigns
      |> assign(:buildings_by_type, Map.new(assigns.buildings, &{&1.type, &1}))
      |> assign(:any_constructing, Enum.any?(assigns.buildings, & &1.construction_finish_at != nil))
      |> assign(:building_layout, @building_layout)

    ~H"""
    <div class="flex flex-col h-screen bg-gray-950 font-sans overflow-hidden select-none">

      <!-- ══════ TOP NAV ══════ -->
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        active_tab="cities"
        galaxy_id={@galaxy_id}
        planet_id={@planet.id}
      />

      <!-- ══════ RESOURCE BAR ══════ -->
      <div class="flex items-center gap-3 bg-gray-950/95 border-b border-gray-800 px-4 h-9 shrink-0 z-20 text-[11px] overflow-x-auto">
        <.res_chip icon="⛏" value={@display.raw_materials} rate={@rates.raw_materials} color="text-amber-300" />
        <.res_chip icon="💾" value={@display.microchips} rate={@rates.microchips} color="text-blue-300" />
        <.res_chip icon="💧" value={@display.hydrogen} rate={@rates.hydrogen} color="text-cyan-300" />
        <.res_chip icon="🌾" value={@display.food} rate={@rates.food} color="text-green-300" />
        <.res_chip icon="💰" value={@display.credits} rate={0.0} color="text-yellow-300" />
        <div class="h-4 w-px bg-gray-700 shrink-0 mx-1" />
        <div class={["flex items-center gap-1 shrink-0 font-semibold",
          if(@rates.energy_balance >= 0, do: "text-emerald-400", else: "text-red-400")]}>
          <span>⚡</span>
          <span>{if @rates.energy_balance >= 0, do: "+", else: ""}{round(@rates.energy_balance * 1.0)}</span>
          <%= if @rates.efficiency < 1.0 do %>
            <span class="text-orange-400 font-normal text-[10px]">({round(@rates.efficiency * 100)}%)</span>
          <% end %>
        </div>
        <div class="flex items-center gap-1 text-purple-300 shrink-0">
          <span>👥</span>
          <span class="font-semibold">{@display.population |> round()}</span>
          <span class="text-gray-500">({format_rate(@rates.population * 1.0)}/h)</span>
        </div>
        <div class="ml-auto flex items-center gap-2 shrink-0">
          <span class="text-cyan-400 font-bold">{@planet.name}</span>
          <%= if @any_constructing do %>
            <% busy = Enum.find(@buildings, & &1.construction_finish_at != nil) %>
            <% {_, _, _} = Enum.find(@building_layout, fn {t, _, _} -> t == busy.type end) || {"", "", {0, 0}} %>
            <% rem_secs = max(0, DateTime.diff(busy.construction_finish_at, @now, :second)) %>
            <span class="text-yellow-400 animate-pulse">⏳ {building_name(busy.type)} → {format_duration(rem_secs)}</span>
          <% end %>
        </div>
      </div>

      <!-- ══════ PLANET MAP ══════ -->
      <div class="relative flex-1 overflow-hidden">
        <img src="/images/planet-images/background.jpg"
             class="absolute inset-0 w-full h-full object-cover"
             draggable="false" />
        <div class="absolute inset-0 bg-black/15" />

        <%= for {type, img, {left, top}} <- @building_layout do %>
          <% b = Map.get(@buildings_by_type, type) %>
          <% level = if b, do: b.level, else: 0 %>
          <% is_constructing = b && b.construction_finish_at != nil %>
          <% is_selected = @selected == type %>
          <button
            phx-click="select_building"
            phx-value-type={type}
            class={[
              "absolute flex flex-col items-center group focus:outline-none transition-all duration-150",
              if(is_selected, do: "z-10", else: "z-0")
            ]}
            style={"left: #{left}%; top: #{top}%; transform: translate(-50%, -50%)"}
          >
            <div class={[
              "relative transition-all duration-150",
              if(is_selected, do: "drop-shadow-[0_0_14px_rgba(6,182,212,0.9)] scale-110", else: "hover:scale-105"),
              if(is_constructing, do: "animate-pulse", else: "")
            ]}>
              <img
                src={"/images/planet-images/#{if level == 0, do: building_img_level0(type), else: img}"}
                class="w-[72px] h-[72px] object-contain drop-shadow-lg"
                draggable="false"
              />
              <%= if is_constructing do %>
                <div class="absolute -top-1 -right-1 w-5 h-5 bg-yellow-400 rounded-full flex items-center justify-center shadow">
                  <span class="text-black text-[9px] font-black">▲</span>
                </div>
              <% end %>
            </div>
            <span class={[
              "mt-0.5 px-1.5 py-0.5 rounded text-[10px] font-semibold whitespace-nowrap shadow-lg",
              if(is_selected,
                do: "bg-cyan-700/95 text-white ring-1 ring-cyan-400",
                else: "bg-black/75 text-gray-200 group-hover:bg-black/90")
            ]}>
              {building_name(type)} ({level})
            </span>
          </button>
        <% end %>
      </div>

      <!-- ══════ BUILDING MODAL ══════ -->
      <%= if @selected do %>
        <%
          sel_b = Map.get(@buildings_by_type, @selected)
          {_, sel_img, _} =
            Enum.find(@building_layout, fn {t, _, _} -> t == @selected end) ||
              {@selected, "unconstructed.png", {0, 0}}
          sel_label        = building_name(@selected)
          sel_level        = if sel_b, do: sel_b.level, else: 0
          sel_next         = sel_level + 1
          sel_constructing = sel_b && sel_b.construction_finish_at != nil
          sel_cost         = ProductionEngine.build_cost(@selected, sel_next)
          sel_secs         = ProductionEngine.build_time_seconds(@selected, sel_next)
          sel_can          = not @any_constructing and ProductionEngine.can_afford?(@planet, sel_cost)
          sel_rem          = if sel_constructing, do: max(0, DateTime.diff(sel_b.construction_finish_at, @now, :second)), else: 0
          sel_total        = if sel_constructing, do: max(1, ProductionEngine.build_time_seconds(@selected, sel_next)), else: 1
          sel_pct          = if sel_constructing, do: trunc((1 - sel_rem / sel_total) * 100), else: 0
          sel_energy_prod  = ProductionEngine.energy_produce_for(@selected, sel_level)
        %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div class="absolute inset-0 bg-black/70 backdrop-blur-sm" phx-click="close_panel" />
          <div class="relative z-10 w-full max-w-2xl bg-gray-900 rounded-2xl border border-gray-700 shadow-2xl overflow-hidden flex flex-col" style="max-height: 88vh">

            <!-- Modal Header: background image + building info -->
            <div class="relative h-44 overflow-hidden shrink-0">
              <img src="/images/planet-images/barraks.jpg"
                   class="absolute inset-0 w-full h-full object-cover" draggable="false" />
              <div class="absolute inset-0 bg-gradient-to-b from-black/20 via-black/40 to-black/90" />
              <button phx-click="close_panel"
                      class="absolute top-3 right-3 w-7 h-7 rounded-full bg-black/60 hover:bg-black/90 text-gray-400 hover:text-white flex items-center justify-center text-sm transition z-10">
                ✕
              </button>
              <div class="absolute bottom-3 left-4 flex items-end gap-3 z-10">
                <img src={"/images/planet-images/#{if sel_level == 0, do: building_img_level0(@selected), else: sel_img}"}
                     class="w-14 h-14 object-contain drop-shadow-2xl rounded" />
                <div>
                  <h2 class="text-white font-bold text-lg leading-tight drop-shadow">{sel_label}</h2>
                  <div class="flex items-center gap-2 mt-0.5">
                    <span class="text-cyan-400 text-sm font-semibold">{gettext("Level")} {sel_level}</span>
                    <%= if sel_constructing do %>
                      <span class="text-yellow-300 text-xs font-medium animate-pulse">⏳ {gettext("Upgrading to level")} {sel_next}</span>
                    <% end %>
                  </div>
                </div>
              </div>
              <%= if sel_constructing do %>
                <div class="absolute bottom-0 left-0 right-0 px-4 pb-2 z-10">
                  <div class="flex items-center gap-2">
                    <div class="flex-1 bg-gray-800/80 rounded-full h-1.5 overflow-hidden">
                      <div class="bg-yellow-400 h-1.5 rounded-full transition-all duration-1000"
                           style={"width: #{sel_pct}%"} />
                    </div>
                    <span class="text-yellow-300 text-xs font-mono tabular-nums shrink-0">{format_duration(sel_rem)}</span>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Tabs -->
            <div class="flex border-b border-gray-800 shrink-0 bg-gray-900">
              <.modal_tab tab="info" selected={@selected_tab} label={gettext("Information")} />
              <.modal_tab tab="specific" selected={@selected_tab} label={gettext("Specific")} />
              <.modal_tab tab="specialization" selected={@selected_tab} label={gettext("Specialization")} />
            </div>

            <!-- Tab Content -->
            <div class="p-5 overflow-y-auto flex-1">

              <!-- ── TAB: Información ── -->
              <%= if @selected_tab == "info" do %>
                <p class="text-gray-400 text-sm leading-relaxed mb-4">{building_description(@selected)}</p>

                <!-- Production stats for resource mines / farms / component_factory -->
                <%= if @selected in ["hydrogen_extractor", "microchip_factory", "mine_raw", "farm", "component_factory"] do %>
                  <% {prod_icon, prod_label, prod_rate} = production_stats(@selected, @rates) %>
                  <div class="bg-gray-800/60 rounded-xl p-3 mb-4 border border-gray-700/60">
                    <h4 class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-2">{prod_label}</h4>
                    <div class="grid grid-cols-4 gap-2 text-center">
                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per minute")}</div>
                        <div class="text-sm font-bold text-emerald-400">{prod_icon} {Float.round(prod_rate / 60.0, 2)}</div>
                      </div>
                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per hour")}</div>
                        <div class="text-sm font-bold text-emerald-400">{prod_icon} {Float.round(prod_rate * 1.0, 1)}</div>
                      </div>
                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per day")}</div>
                        <div class="text-sm font-bold text-emerald-400">{prod_icon} {Float.round(prod_rate * 24.0, 1)}</div>
                      </div>
                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per week")}</div>
                        <div class="text-sm font-bold text-emerald-400">{prod_icon} {Float.round(prod_rate * 168.0, 0)}</div>
                      </div>
                    </div>
                  </div>
                <% end %>

                <!-- Energy stats for generators (static balance, not flowing resource) -->
                <%= if @selected in ["power_plant", "nuclear_reactor"] do %>
                  <div class="bg-gray-800/60 rounded-xl p-3 mb-4 border border-gray-700/60">
                    <h4 class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">{gettext("Energy Production")}</h4>
                    <div class="grid grid-cols-2 gap-3 mb-3">
                      <div class="bg-gray-900/60 rounded-lg p-2.5 text-center">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("This building produces")}</div>
                        <div class="text-xl font-bold text-yellow-400">⚡ {round(sel_energy_prod)}</div>
                        <div class="text-[10px] text-gray-500 mt-0.5">{gettext("energy at current level")}</div>
                      </div>
                      <div class="bg-gray-900/60 rounded-lg p-2.5 text-center">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Planet Balance")}</div>
                        <div class={["text-xl font-bold", if(@rates.energy_balance >= 0, do: "text-emerald-400", else: "text-red-400")]}>
                          {if @rates.energy_balance >= 0, do: "+", else: ""}{round(@rates.energy_balance)}
                        </div>
                        <div class="text-[10px] text-gray-500 mt-0.5">{round(@rates.efficiency * 100)}% {gettext("efficiency")}</div>
                      </div>
                    </div>
                    <div class="bg-gray-900/60 rounded-lg px-3 py-2 flex items-center justify-between text-xs">
                      <div>
                        <span class="text-emerald-400 font-semibold">+{round(@rates.energy_produce)}</span>
                        <span class="text-gray-500 ml-1">{gettext("produced")}</span>
                      </div>
                      <div>
                        <span class="text-red-400 font-semibold">-{round(@rates.energy_consume)}</span>
                        <span class="text-gray-500 ml-1">{gettext("consumed")}</span>
                      </div>
                    </div>
                  </div>
                <% end %>

                <!-- Upgrade section -->
                <div class="border-t border-gray-800 pt-4">
                  <h4 class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                    {if sel_level == 0, do: gettext("Initial Construction"), else: "#{gettext("Upgrade → Level")} #{sel_next}"}
                  </h4>
                  <%= if sel_constructing do %>
                    <div class="flex items-center justify-between bg-yellow-950/40 rounded-xl px-4 py-3 border border-yellow-800/50">
                      <div>
                        <p class="text-yellow-300 text-sm font-semibold">⏳ {gettext("Construction in progress")}</p>
                        <p class="text-yellow-600 text-xs mt-0.5">{gettext("Upgrading to level")} {sel_next}</p>
                      </div>
                      <div class="text-right">
                        <p class="text-yellow-200 text-2xl font-mono font-bold tabular-nums">{format_duration(sel_rem)}</p>
                        <p class="text-yellow-700 text-[10px]">{gettext("remaining")}</p>
                      </div>
                    </div>
                  <% else %>
                    <div class="flex flex-wrap gap-x-5 gap-y-1.5 mb-3">
                      <span class="text-gray-500 text-xs">⏱ {format_duration(sel_secs)}</span>
                      <%= for {resource, amount} <- sel_cost do %>
                        <span class={[
                          "text-xs",
                          if(Map.get(@planet, resource, 0) >= amount,
                            do: "text-gray-300",
                            else: "text-red-400 font-semibold")
                        ]}>
                          {resource_label(resource)}: {amount}
                        </span>
                      <% end %>
                    </div>
                    <%= if @any_constructing do %>
                      <p class="text-yellow-500 text-xs">⚠ {gettext("A construction is already in progress on this planet.")}</p>
                    <% else %>
                      <button
                        phx-click="build"
                        phx-value-type={@selected}
                        disabled={not sel_can}
                        class={[
                          "py-2 px-6 rounded-lg text-sm font-bold transition",
                          if(sel_can,
                            do: "bg-cyan-700 hover:bg-cyan-600 text-white cursor-pointer",
                            else: "bg-gray-800 text-gray-600 cursor-not-allowed")
                        ]}
                      >
                        {if sel_level == 0, do: gettext("Build"), else: "#{gettext("Upgrade → Level")} #{sel_next}"}
                      </button>
                    <% end %>
                    <%= if @error do %>
                      <p class="text-red-400 text-xs mt-2">{@error}</p>
                    <% end %>
                  <% end %>
                </div>
              <% end %>

              <!-- ── TAB: Específico ── -->
              <%= if @selected_tab == "specific" do %>
                <div class="flex flex-col items-center justify-center h-36 text-center gap-2">
                  <span class="text-4xl">🔧</span>
                  <p class="text-gray-500 text-sm">{gettext("Specific structure information coming soon.")}</p>
                </div>
              <% end %>

              <!-- ── TAB: Especialización ── -->
              <%= if @selected_tab == "specialization" do %>
                <div class="flex flex-col items-center justify-center h-36 text-center gap-2">
                  <span class="text-4xl">⭐</span>
                  <p class="text-gray-500 text-sm">{gettext("Specialization system coming soon.")}</p>
                </div>
              <% end %>

            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :icon, :string, required: true
  attr :value, :float, required: true
  attr :rate, :float, required: true
  attr :color, :string, required: true

  defp res_chip(assigns) do
    ~H"""
    <div class="flex items-center gap-1 shrink-0">
      <span>{@icon}</span>
      <span class={["font-semibold tabular-nums", @color]}>{format_resource(@value)}</span>
      <span class={["text-[10px]", if(@rate > 0, do: "text-emerald-500", else: "text-gray-600")]}>
        {format_rate(@rate)}/h
      </span>
    </div>
    """
  end

  attr :tab, :string, required: true
  attr :selected, :string, required: true
  attr :label, :string, required: true

  defp modal_tab(assigns) do
    ~H"""
    <button
      phx-click="select_tab"
      phx-value-tab={@tab}
      class={[
        "px-5 py-3 text-sm font-medium transition-colors border-b-2 -mb-px",
        if(@selected == @tab,
          do: "text-cyan-300 border-cyan-500",
          else: "text-gray-500 border-transparent hover:text-gray-300 hover:border-gray-600")
      ]}
    >
      {@label}
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("select_building", %{"type" => type}, socket) do
    selected = if socket.assigns.selected == type, do: nil, else: type
    {:noreply, assign(socket, selected: selected, selected_tab: "info", error: nil)}
  end

  def handle_event("close_panel", _params, socket) do
    {:noreply, assign(socket, selected: nil, error: nil)}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  def handle_event("toggle_user_menu", _params, socket) do
    {:noreply, assign(socket, :show_user_menu, !socket.assigns.show_user_menu)}
  end

  def handle_event("build", %{"type" => building_type}, socket) do
    planet_id = socket.assigns.planet.id

    case Planets.start_construction(planet_id, building_type) do
      {:ok, _building} ->
        planet   = Planets.get_planet!(planet_id)
        buildings = Planets.list_buildings(planet_id)
        rates    = ProductionEngine.calculate_rates(buildings)

        {:noreply,
         socket
         |> assign(:planet, planet)
         |> assign(:buildings, buildings)
         |> assign(:rates, rates)
         |> assign(:display, resource_display(planet))
         |> assign(:error, nil)}

      {:error, :already_constructing} ->
        {:noreply, assign(socket, :error, gettext("A construction is already in progress on this planet."))}

      {:error, :planet_busy} ->
        {:noreply, assign(socket, :error, gettext("A construction is already in progress on this planet."))}

      {:error, :insufficient_resources} ->
        {:noreply, assign(socket, :error, gettext("Insufficient resources to start construction."))}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  # ---------------------------------------------------------------------------
  # Timer
  # ---------------------------------------------------------------------------

  def handle_info(:ui_tick, socket) do
    schedule_ui_tick()
    now    = DateTime.utc_now()
    planet = socket.assigns.planet
    rates  = socket.assigns.rates

    elapsed_secs  = DateTime.diff(now, planet.last_tick_at, :second)
    elapsed_hours = elapsed_secs / 3600.0

    display = %{
      raw_materials: planet.raw_materials + rates.raw_materials * elapsed_hours,
      microchips:    planet.microchips    + rates.microchips    * elapsed_hours,
      hydrogen:      planet.hydrogen      + rates.hydrogen      * elapsed_hours,
      food:          planet.food          + rates.food          * elapsed_hours,
      credits:       planet.credits,
      population:    (planet.population + round(rates.population * elapsed_hours)) * 1.0
    }

    last_persist     = socket.assigns.last_persist
    secs_since_persist = DateTime.diff(now, last_persist, :second)

    {new_planet, new_last_persist} =
      if secs_since_persist >= @db_persist_secs do
        case Planets.apply_production_tick(planet) do
          {:ok, updated} -> {updated, now}
          _              -> {planet, last_persist}
        end
      else
        {planet, last_persist}
      end

    updated_buildings = Planets.list_buildings(planet.id)
    new_rates         = ProductionEngine.calculate_rates(updated_buildings)

    {:noreply,
     socket
     |> assign(:now, now)
     |> assign(:planet, new_planet)
     |> assign(:buildings, updated_buildings)
     |> assign(:rates, new_rates)
     |> assign(:display, display)
     |> assign(:last_persist, new_last_persist)}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp schedule_ui_tick, do: Process.send_after(self(), :ui_tick, @ui_tick_ms)

  defp resource_display(planet) do
    %{
      raw_materials: planet.raw_materials * 1.0,
      microchips:    planet.microchips    * 1.0,
      hydrogen:      planet.hydrogen      * 1.0,
      food:          planet.food          * 1.0,
      credits:       planet.credits       * 1.0,
      population:    planet.population    * 1.0
    }
  end

  defp format_rate(rate) when is_float(rate) or is_integer(rate) do
    r = rate * 1.0
    if r >= 0, do: "+#{Float.round(r, 1)}", else: "#{Float.round(r, 1)}"
  end

  defp format_resource(v) when v >= 1_000_000, do: "#{Float.round(v / 1_000_000.0, 1)}M"
  defp format_resource(v) when v >= 10_000,    do: "#{round(v / 1_000)}k"
  defp format_resource(v) when v >= 100,       do: "#{round(v * 1.0)}"
  defp format_resource(v),                     do: "#{Float.round(v * 1.0, 1)}"

  defp format_duration(secs) when secs <= 0, do: "0s"
  defp format_duration(secs) when secs < 60, do: "#{secs}s"
  defp format_duration(secs) when secs < 3600, do: "#{div(secs, 60)}m #{rem(secs, 60)}s"
  defp format_duration(secs), do: "#{div(secs, 3600)}h #{div(rem(secs, 3600), 60)}m"

  defp resource_label(:raw_materials), do: gettext("Raw Materials")
  defp resource_label(:microchips), do: gettext("Chips")
  defp resource_label(:hydrogen), do: gettext("Hydrogen")
  defp resource_label(:food), do: gettext("Food")
  defp resource_label(:credits), do: gettext("Credits")
  defp resource_label(other), do: other |> to_string() |> String.capitalize()

  # Return a level-0 placeholder image for buildings not yet built
  defp building_img_level0("farm"), do: "unconstructed2.png"
  defp building_img_level0("residential"), do: "unconstructed3.png"
  defp building_img_level0(_), do: "unconstructed.png"

  defp building_description("hydrogen_extractor"), do: gettext("Extracts hydrogen from atmospheric layers using advanced molecular separators. Hydrogen is vital for propelling fleets and powering fusion reactors.")
  defp building_description("microchip_factory"),  do: gettext("Manufactures high-precision quantum microchips for ship construction and advanced technologies. Higher level means better performance and lower defect rate.")
  defp building_description("spaceport"),          do: gettext("Fleet operations center. Manages launches, landings and maintenance. Enables trade routes, exploration missions and combat operations.")
  defp building_description("residential"),        do: gettext("Residential zone housing the planet's population. Higher levels increase capacity and quality of life, attracting new colonists to the system.")
  defp building_description("command_center"),     do: gettext("The planet's nerve center. Coordinates all administrative, military and civilian operations. Its level determines the expansion limits of other structures.")
  defp building_description("mine_raw"),           do: gettext("Extracts raw materials from the planetary subsoil with high-energy plasma drills. A fundamental resource for all construction and research.")
  defp building_description("farm"),               do: gettext("Hydroponic crops and bioreactors that produce food for the population. Without sufficient supply, overall productive efficiency decreases.")
  defp building_description("laboratory"),         do: gettext("Scientific and technological research center. Accelerates the development of new technologies and unlocks synergistic improvements for other structures.")
  defp building_description("power_plant"),        do: gettext("Generates the energy needed to keep all planetary structures operational. A negative energy balance reduces overall productive efficiency.")
  defp building_description("nuclear_reactor"),    do: gettext("High-efficiency nuclear fission reactor. Produces more energy per level than the conventional generator, ideal for planets with high industrial demand.")
  defp building_description("defense_center"),     do: gettext("Planetary defense coordination center. Manages turrets, shields and early warning systems to protect the planet from external attacks.")
  defp building_description("component_factory"),  do: gettext("Factory specialized in advanced electronic components. Complements microchip production with a higher-precision manufacturing chain.")
  defp building_description(_),                    do: gettext("Planetary structure.")

  defp production_stats("hydrogen_extractor", rates), do: {"\u{1F4A7}", gettext("Hydrogen Production"),         rates.hydrogen * 1.0}
  defp production_stats("microchip_factory",  rates), do: {"\u{1F4BE}", gettext("Microchip Production"),          rates.microchips * 1.0}
  defp production_stats("mine_raw",           rates), do: {"\u26CF\uFE0F",  gettext("Raw Materials Production"),   rates.raw_materials * 1.0}
  defp production_stats("farm",               rates), do: {"\u{1F33E}", gettext("Food Production"),                rates.food * 1.0}
  defp production_stats("component_factory",  rates), do: {"\u{1F4BE}", gettext("Microchip Production"),          rates.microchips * 1.0}
  defp production_stats(_,                    _rates), do: {"\u{1F4E6}", gettext("Production"),                    0.0}

  defp building_name("hydrogen_extractor"), do: gettext("Hydrogen Mine")
  defp building_name("microchip_factory"),  do: gettext("Chip Factory")
  defp building_name("spaceport"),          do: gettext("Spaceport")
  defp building_name("residential"),        do: gettext("Residential Area")
  defp building_name("command_center"),     do: gettext("Command Center")
  defp building_name("mine_raw"),           do: gettext("Raw Material Mine")
  defp building_name("farm"),               do: gettext("Farm")
  defp building_name("laboratory"),         do: gettext("Research Center")
  defp building_name("power_plant"),        do: gettext("Energy Generator")
  defp building_name("nuclear_reactor"),    do: gettext("Nuclear Reactor")
  defp building_name("defense_center"),     do: gettext("Defense Center")
  defp building_name("component_factory"),  do: gettext("Component Factory")
  defp building_name(type),                 do: type
end
