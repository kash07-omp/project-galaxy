defmodule NexusDownfallWeb.PlanetLive do
  @moduledoc "Planetary management screen — Ikariam-style map view."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.ProductionEngine

  @ui_tick_ms 1_000
  @db_persist_secs 60

  # {db_type, image_file, display_name, {left_pct, top_pct}}
  @building_layout [
    {"hydrogen_extractor", "hydrogen-mine.png",      "Mina de Hidrógeno",  {22, 12}},
    {"microchip_factory",  "microchip-factory.png",  "Fábrica de Chips",   {50, 18}},
    {"spaceport",          "spaceport.png",           "Puerto Espacial",    {72, 16}},
    {"residential",        "residential-area.png",    "Zona Residencial",   {20, 43}},
    {"command_center",     "city-hall.png",           "Centro de Mando",    {46, 50}},
    {"mine_raw",           "raw-material-mine.png",   "Mina de Recursos",   {64, 40}},
    {"farm",               "farmland.png",            "Granja",             {9, 62}},
    {"laboratory",         "research-center.png",     "Centro de Investigación", {58, 70}},
    {"power_plant",        "energy-generator.png",    "Generador",          {80, 54}}
  ]

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  def mount(%{"id" => planet_id}, _session, socket) do
    {:ok, buildings} = Planets.ensure_building_slots(planet_id)
    {:ok, planet} = Planets.apply_production_tick(Planets.get_planet!(planet_id))
    rates = ProductionEngine.calculate_rates(buildings)

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
      <nav class="flex items-center justify-between bg-gray-900/95 border-b border-gray-800 px-3 h-10 shrink-0 z-30 backdrop-blur">
        <.link navigate={~p"/dashboard"} class="flex items-center gap-1.5 shrink-0">
          <span class="text-cyan-400 text-base">⬡</span>
          <span class="text-white font-bold tracking-widest text-xs uppercase">Nexus</span>
          <span class="text-cyan-400 font-bold text-xs">:</span>
          <span class="text-cyan-300 font-bold tracking-widest text-xs uppercase">Downfall</span>
        </.link>

        <div class="flex items-center gap-0.5 text-[11px] font-medium overflow-x-auto px-2">
          <.nav_tab href={~p"/dashboard"} label="Galaxia" active={false} />
          <.nav_tab href={~p"/planets/#{@planet.id}"} label="Ciudades" active={true} />
          <.nav_tab href="#" label="Investigación" active={false} />
          <.nav_tab href="#" label="Leyes" active={false} />
          <.nav_tab href="#" label="Comercio" active={false} />
          <.nav_tab href="#" label="Diplomacia" active={false} />
          <.nav_tab href="#" label="Clanes" active={false} />
          <.nav_tab href="#" label="Cartas" active={false} />
          <.nav_tab href="#" label="Flota" active={false} />
          <.nav_tab href="#" label="Ranking" active={false} />
          <.nav_tab href="#" label="Tienda" active={false} />
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <span class="text-gray-400 text-xs hidden sm:block">{player_name(@current_user)}</span>
          <div class="w-7 h-7 rounded-full bg-cyan-800 border-2 border-cyan-600 flex items-center justify-center text-xs font-bold text-white uppercase">
            {String.first(player_name(@current_user))}
          </div>
        </div>
      </nav>

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
          <span>{format_rate(@rates.energy_balance)}/h</span>
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
            <% {_, _, busy_label, _} = Enum.find(@building_layout, fn {t, _, _, _} -> t == busy.type end) || {"", "", busy.type, {0, 0}} %>
            <% rem_secs = max(0, DateTime.diff(busy.construction_finish_at, @now, :second)) %>
            <span class="text-yellow-400 animate-pulse">⏳ {busy_label} → {format_duration(rem_secs)}</span>
          <% end %>
        </div>
      </div>

      <!-- ══════ PLANET MAP ══════ -->
      <div class="relative flex-1 overflow-hidden">
        <img src="/images/planet-images/background.jpg"
             class="absolute inset-0 w-full h-full object-cover"
             draggable="false" />
        <div class="absolute inset-0 bg-black/15" />

        <%= for {type, img, label, {left, top}} <- @building_layout do %>
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
              {label} ({level})
            </span>
          </button>
        <% end %>
      </div>

      <!-- ══════ BUILDING PANEL (bottom slide-in) ══════ -->
      <%= if @selected do %>
        <%
          sel_b = Map.get(@buildings_by_type, @selected)
          {_, sel_img, sel_label, _} =
            Enum.find(@building_layout, fn {t, _, _, _} -> t == @selected end) ||
              {@selected, "unconstructed.png", @selected, {0, 0}}
          sel_level = if sel_b, do: sel_b.level, else: 0
          sel_next  = sel_level + 1
          sel_constructing = sel_b && sel_b.construction_finish_at != nil
          sel_cost  = ProductionEngine.build_cost(@selected, sel_next)
          sel_secs  = ProductionEngine.build_time_seconds(@selected, sel_next)
          sel_can   = not @any_constructing and ProductionEngine.can_afford?(@planet, sel_cost)
          sel_rem   = if sel_constructing, do: max(0, DateTime.diff(sel_b.construction_finish_at, @now, :second)), else: 0
          sel_total = if sel_constructing, do: ProductionEngine.build_time_seconds(@selected, sel_next), else: 1
          sel_pct   = if sel_constructing and sel_total > 0, do: trunc((1 - sel_rem / sel_total) * 100), else: 0
        %>
        <div class="shrink-0 bg-gray-900/98 border-t-2 border-cyan-800 z-30 backdrop-blur">
          <div class="flex items-start gap-4 px-4 py-3 max-w-5xl mx-auto">

            <!-- Icon -->
            <img src={"/images/planet-images/#{sel_img}"}
                 class="w-16 h-16 object-contain shrink-0 rounded" />

            <!-- Content -->
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-2">
                <h3 class="text-cyan-200 font-bold text-sm">{sel_label}</h3>
                <span class="text-[11px] bg-cyan-900/70 text-cyan-400 px-2 py-0.5 rounded-full border border-cyan-800">
                  Nivel {sel_level}
                </span>
                <%= if sel_constructing do %>
                  <span class="text-[11px] bg-yellow-900/70 text-yellow-300 px-2 py-0.5 rounded-full border border-yellow-700 animate-pulse">
                    ⏳ Mejorando → Lv {sel_next}
                  </span>
                <% end %>
              </div>

              <%= if sel_constructing do %>
                <div class="flex items-center gap-3">
                  <div class="flex-1 bg-gray-800 rounded-full h-2 overflow-hidden">
                    <div class="bg-yellow-400 h-2 rounded-full transition-all duration-1000"
                         style={"width: #{sel_pct}%"} />
                  </div>
                  <span class="text-yellow-300 text-sm font-mono tabular-nums shrink-0 min-w-[5rem] text-right">
                    {format_duration(sel_rem)}
                  </span>
                </div>
              <% else %>
                <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-400 mb-2">
                  <span class="text-gray-500">→ Nivel {sel_next}</span>
                  <span class="text-gray-600">⏱ {format_duration(sel_secs)}</span>
                  <%= for {resource, amount} <- sel_cost do %>
                    <span class={[
                      if(Map.get(@planet, resource, 0) >= amount, do: "text-gray-300", else: "text-red-400 font-semibold")
                    ]}>
                      {resource_label(resource)}: {amount}
                    </span>
                  <% end %>
                </div>

                <%= if @any_constructing do %>
                  <p class="text-yellow-500 text-xs">⚠ Solo puedes construir una estructura a la vez. Espera a que termine.</p>
                <% else %>
                  <button
                    phx-click="build"
                    phx-value-type={@selected}
                    disabled={not sel_can}
                    class={[
                      "py-1 px-5 rounded text-xs font-bold transition",
                      if(sel_can,
                        do: "bg-cyan-700 hover:bg-cyan-600 text-white cursor-pointer",
                        else: "bg-gray-800 text-gray-600 cursor-not-allowed"
                      )
                    ]}
                  >
                    {if sel_level == 0, do: "Construir", else: "Mejorar a Lv #{sel_next}"}
                  </button>
                <% end %>
              <% end %>

              <%= if @error do %>
                <p class="text-red-400 text-xs mt-1">{@error}</p>
              <% end %>
            </div>

            <button phx-click="close_panel"
                    class="text-gray-500 hover:text-white text-lg leading-none shrink-0 mt-0.5">
              ✕
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true

  defp nav_tab(assigns) do
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

  attr :icon, :string, required: true
  attr :value, :float, required: true
  attr :rate, :float, required: true
  attr :color, :string, required: true

  defp res_chip(assigns) do
    ~H"""
    <div class="flex items-center gap-1 shrink-0">
      <span>{@icon}</span>
      <span class={["font-semibold tabular-nums", @color]}>{@value |> round()}</span>
      <span class={["text-[10px]", if(@rate > 0, do: "text-emerald-500", else: "text-gray-600")]}>
        {format_rate(@rate)}/h
      </span>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("select_building", %{"type" => type}, socket) do
    selected = if socket.assigns.selected == type, do: nil, else: type
    {:noreply, assign(socket, selected: selected, error: nil)}
  end

  def handle_event("close_panel", _params, socket) do
    {:noreply, assign(socket, selected: nil, error: nil)}
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
        {:noreply, assign(socket, :error, "Este edificio ya está siendo mejorado.")}

      {:error, :planet_busy} ->
        {:noreply, assign(socket, :error, "Ya hay una construcción en progreso en este planeta.")}

      {:error, :insufficient_resources} ->
        {:noreply, assign(socket, :error, "Recursos insuficientes para iniciar la construcción.")}

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

  defp player_name(user) do
    user.email |> String.split("@") |> List.first()
  end

  defp format_rate(rate) when is_float(rate) or is_integer(rate) do
    r = rate * 1.0
    if r >= 0, do: "+#{Float.round(r, 1)}", else: "#{Float.round(r, 1)}"
  end

  defp format_duration(secs) when secs <= 0, do: "0s"
  defp format_duration(secs) when secs < 60, do: "#{secs}s"
  defp format_duration(secs) when secs < 3600, do: "#{div(secs, 60)}m #{rem(secs, 60)}s"
  defp format_duration(secs), do: "#{div(secs, 3600)}h #{div(rem(secs, 3600), 60)}m"

  defp resource_label(:raw_materials), do: "Recursos"
  defp resource_label(:microchips), do: "Chips"
  defp resource_label(:hydrogen), do: "Hidrógeno"
  defp resource_label(:food), do: "Comida"
  defp resource_label(:credits), do: "Créditos"
  defp resource_label(other), do: other |> to_string() |> String.capitalize()

  # Return a level-0 placeholder image for buildings not yet built
  defp building_img_level0("farm"), do: "unconstructed2.png"
  defp building_img_level0("residential"), do: "unconstructed3.png"
  defp building_img_level0(_), do: "unconstructed.png"
end
