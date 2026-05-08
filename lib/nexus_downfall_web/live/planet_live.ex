defmodule NexusDownfallWeb.PlanetLive do
  @moduledoc "Planetary management screen — Ikariam-style map view."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Fleets
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.Defenses
  alias NexusDownfall.Planets.ProductionEngine
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.SolarSystem

  @ui_tick_ms 1_000

  # {db_type, image_file, {left_pct, top_pct}}
  @building_layout [
    {"hydrogen_extractor", "hydrogen-mine.png", {22, 12}},
    {"microchip_factory", "microchip-factory.png", {50, 18}},
    {"spaceport", "spaceport.png", {72, 16}},
    {"residential", "residential-area.png", {20, 43}},
    {"command_center", "city-hall.png", {46, 50}},
    {"mine_raw", "raw-material-mine.png", {64, 40}},
    {"farm", "farmland.png", {9, 62}},
    {"laboratory", "research-center.png", {58, 70}},
    {"power_plant", "energy-generator.png", {80, 54}},
    {"nuclear_reactor", "nuclear-reactor.png", {92, 70}},
    {"defense_center", "defense-center.png", {35, 82}},
    {"component_factory", "microchip-factory.png", {65, 80}}
  ]

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  def mount(%{"id" => planet_id}, _session, socket) do
    current_user_id = socket.assigns.current_user.id

    case safe_load_planet_state(planet_id, current_user_id) do
      {:ok, {planet, buildings, rates, display, now}} ->
        shipyard = Fleets.shipyard_panel_for_user_planet(planet_id, current_user_id)
        defense_panel = Defenses.defense_panel_for_user_planet(planet_id, current_user_id)

        # Load galaxy_id for nav link
        system = Repo.get!(SolarSystem, planet.solar_system_id)
        galaxy_id = system.galaxy_id

        if connected?(socket), do: schedule_ui_tick()

        {:ok,
         socket
         |> assign(:planet, planet)
         |> assign(:buildings, buildings)
         |> assign(:rates, rates)
         |> assign(:display, display)
         |> assign(:now, now)
         |> assign(:spaceport_fleets, shipyard.fleets)
         |> assign(:shipyard_queue_items, shipyard.queue_items)
         |> assign(:ship_catalog, shipyard.ship_catalog)
         |> assign(:planet_defenses, defense_panel.defenses)
         |> assign(:defense_queue_items, defense_panel.queue_items)
         |> assign(:defense_catalog, defense_panel.defense_catalog)
         |> assign(:selected, nil)
         |> assign(:selected_tab, "info")
         |> assign(:show_user_menu, false)
         |> assign(:galaxy_id, galaxy_id)
         |> assign(:dev_tools_enabled, Mix.env() != :prod)
         |> assign(:error, nil)
         |> assign(:shipyard_error, nil)
         |> assign(:shipyard_notice, nil)
         |> assign(:build_order, %{})
         |> assign(:defense_error, nil)
         |> assign(:defense_notice, nil)
         |> assign(:defense_order, %{})
         |> assign(:selected_unit_details, nil)
         |> assign(
           :selected_fleet_id,
           case shipyard.fleets do
             [f | _] -> to_string(f.id)
             [] -> nil
           end
         )}

      {:error, :not_found} ->
        {:ok, redirect(socket, to: ~p"/404")}
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    assigns =
      assigns
      |> assign(:buildings_by_type, Map.new(assigns.buildings, &{&1.type, &1}))
      |> assign(
        :any_constructing,
        Enum.any?(assigns.buildings, &(&1.construction_finish_at != nil))
      )
      |> assign(:building_layout, @building_layout)
      |> assign(:unit_detail, selected_unit_detail(assigns.selected_unit_details))

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
        <.res_chip
          icon="⛏"
          value={@display.raw_materials}
          rate={@rates.raw_materials}
          color="text-amber-300"
        />
        <.res_chip
          icon="💾"
          value={@display.microchips}
          rate={@rates.microchips}
          color="text-blue-300"
        />
        <.res_chip icon="💧" value={@display.hydrogen} rate={@rates.hydrogen} color="text-cyan-300" />
        <.res_chip icon="🌾" value={@display.food} rate={@rates.food} color="text-green-300" />
        <.res_chip icon="💰" value={@display.credits} rate={0.0} color="text-yellow-300" />
        <div class="h-4 w-px bg-gray-700 shrink-0 mx-1" />
        <div class={[
          "flex items-center gap-1 shrink-0 font-semibold",
          if(@rates.energy_balance >= 0, do: "text-emerald-400", else: "text-red-400")
        ]}>
          <span>⚡</span>
          <span>
            {if @rates.energy_balance >= 0, do: "+", else: ""}{round(@rates.energy_balance * 1.0)}
          </span>
          <%= if @rates.efficiency < 1.0 do %>
            <span class="text-orange-400 font-normal text-[10px]">
              ({round(@rates.efficiency * 100)}%)
            </span>
          <% end %>
        </div>

        <div class="flex items-center gap-1 text-purple-300 shrink-0">
          <span>👥</span> <span class="font-semibold">{@display.population |> round()}</span>
          <span class="text-gray-500">({format_rate(@rates.population * 1.0)}/h)</span>
        </div>

        <div class="ml-auto flex items-center gap-2 shrink-0">
          <span class="text-cyan-400 font-bold">{@planet.name}</span>
          <%= if @any_constructing do %>
            <% busy = Enum.find(@buildings, &(&1.construction_finish_at != nil)) %> <% {_, _, _} =
              Enum.find(@building_layout, fn {t, _, _} -> t == busy.type end) || {"", "", {0, 0}} %> <% rem_secs =
              max(0, DateTime.diff(busy.construction_finish_at, @now, :second)) %>
            <span class="text-yellow-400 animate-pulse">
              ⏳ {building_name(busy.type)} → {format_duration(rem_secs)}
            </span>
          <% end %>
        </div>
      </div>
      <!-- ══════ PLANET MAP ══════ -->
      <div class="relative flex-1 overflow-hidden">
        <img
          src="/images/planet-images/background.jpg"
          class="absolute inset-0 w-full h-full object-cover"
          draggable="false"
        /> <div class="absolute inset-0 bg-black/15" />
        <%= for {type, img, {left, top}} <- @building_layout do %>
          <% b = Map.get(@buildings_by_type, type) %> <% level = if b, do: b.level, else: 0 %> <% is_constructing =
            b && b.construction_finish_at != nil %> <% is_selected = @selected == type %>
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
              if(is_selected,
                do: "drop-shadow-[0_0_14px_rgba(6,182,212,0.9)] scale-110",
                else: "hover:scale-105"
              ),
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
                else: "bg-black/75 text-gray-200 group-hover:bg-black/90"
              )
            ]}>
              {building_name(type)} ({level})
            </span>
          </button>
        <% end %>
      </div>
      <!-- ══════ BUILDING MODAL ══════ -->
      <%= if @selected do %>
        <% sel_b = Map.get(@buildings_by_type, @selected)

        {_, sel_img, _} =
          Enum.find(@building_layout, fn {t, _, _} -> t == @selected end) ||
            {@selected, "unconstructed.png", {0, 0}}

        sel_label = building_name(@selected)
        sel_level = if sel_b, do: sel_b.level, else: 0
        sel_next = sel_level + 1
        sel_constructing = sel_b && sel_b.construction_finish_at != nil
        sel_cost = ProductionEngine.build_cost(@selected, sel_next)
        sel_secs = ProductionEngine.build_time_seconds(@selected, sel_next)
        sel_can = not @any_constructing and ProductionEngine.can_afford?(@planet, sel_cost)

        sel_rem =
          if sel_constructing,
            do: max(0, DateTime.diff(sel_b.construction_finish_at, @now, :second)),
            else: 0

        sel_total =
          if sel_constructing,
            do: max(1, ProductionEngine.build_time_seconds(@selected, sel_next)),
            else: 1

        sel_pct = if sel_constructing, do: trunc((1 - sel_rem / sel_total) * 100), else: 0
        sel_energy_prod = ProductionEngine.energy_produce_for(@selected, sel_level) %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div class="absolute inset-0 bg-black/70 backdrop-blur-sm" phx-click="close_panel" />
          <div
            class={[
              "relative z-10 w-full bg-gray-900 rounded-2xl border border-gray-700 shadow-2xl overflow-hidden flex flex-col",
              if(@selected in ["spaceport", "defense_center"] and @selected_tab == "specific",
                do: "max-w-6xl",
                else: "max-w-3xl"
              )
            ]}
            style="max-height: 88vh"
          >
            <!-- Modal Header: background image + building info -->
            <div class="relative h-44 overflow-hidden shrink-0">
              <img
                src="/images/planet-images/barraks.jpg"
                class="absolute inset-0 w-full h-full object-cover"
                draggable="false"
              />
              <div class="absolute inset-0 bg-gradient-to-b from-black/20 via-black/40 to-black/90" />
              <button
                phx-click="close_panel"
                class="absolute top-3 right-3 w-7 h-7 rounded-full bg-black/60 hover:bg-black/90 text-gray-400 hover:text-white flex items-center justify-center text-sm transition z-10"
              >
                ✕
              </button>
              <div class="absolute bottom-3 left-4 flex items-end gap-3 z-10">
                <img
                  src={"/images/planet-images/#{if sel_level == 0, do: building_img_level0(@selected), else: sel_img}"}
                  class="w-14 h-14 object-contain drop-shadow-2xl rounded"
                />
                <div>
                  <h2 class="text-white font-bold text-lg leading-tight drop-shadow">{sel_label}</h2>

                  <div class="flex items-center gap-2 mt-0.5">
                    <span class="text-cyan-400 text-sm font-semibold">
                      {gettext("Level")} {sel_level}
                    </span>
                    <%= if sel_constructing do %>
                      <span class="text-yellow-300 text-xs font-medium animate-pulse">
                        ⏳ {gettext("Upgrading to level")} {sel_next}
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>

              <%= if sel_constructing do %>
                <div class="absolute bottom-0 left-0 right-0 px-4 pb-2 z-10">
                  <div class="flex items-center gap-2">
                    <div class="flex-1 bg-gray-800/80 rounded-full h-1.5 overflow-hidden">
                      <div
                        class="bg-yellow-400 h-1.5 rounded-full transition-all duration-1000"
                        style={"width: #{sel_pct}%"}
                      />
                    </div>

                    <span class="text-yellow-300 text-xs font-mono tabular-nums shrink-0">
                      {format_duration(sel_rem)}
                    </span>
                  </div>
                </div>
              <% end %>
            </div>
            <!-- Tabs -->
            <div class="flex border-b border-gray-800 shrink-0 bg-gray-900">
              <.modal_tab tab="info" selected={@selected_tab} label={gettext("Information")} />
              <.modal_tab tab="specific" selected={@selected_tab} label={gettext("Specific")} />
              <.modal_tab
                tab="specialization"
                selected={@selected_tab}
                label={gettext("Specialization")}
              />
            </div>
            <!-- Tab Content -->
            <div class={[
              "overflow-y-auto flex-1",
              if(@selected in ["spaceport", "defense_center"] and @selected_tab == "specific",
                do: "overflow-hidden flex flex-col",
                else: "p-5"
              )
            ]}>
              <!-- ── TAB: Información ── -->
              <%= if @selected_tab == "info" do %>
                <p class="text-gray-400 text-sm leading-relaxed mb-4">
                  {building_description(@selected)}
                </p>
                <!-- Production stats for resource mines / farms / component_factory -->
                <%= if @selected in ["hydrogen_extractor", "microchip_factory", "mine_raw", "farm", "component_factory"] do %>
                  <% {prod_icon, prod_label, prod_rate} = production_stats(@selected, @rates) %>
                  <div class="bg-gray-800/60 rounded-xl p-3 mb-4 border border-gray-700/60">
                    <h4 class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-2">
                      {prod_label}
                    </h4>

                    <div class="grid grid-cols-4 gap-2 text-center">
                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per minute")}</div>

                        <div class="text-sm font-bold text-emerald-400">
                          {prod_icon} {Float.round(prod_rate / 60.0, 2)}
                        </div>
                      </div>

                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per hour")}</div>

                        <div class="text-sm font-bold text-emerald-400">
                          {prod_icon} {Float.round(prod_rate * 1.0, 1)}
                        </div>
                      </div>

                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per day")}</div>

                        <div class="text-sm font-bold text-emerald-400">
                          {prod_icon} {Float.round(prod_rate * 24.0, 1)}
                        </div>
                      </div>

                      <div class="bg-gray-900/60 rounded-lg p-2">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Per week")}</div>

                        <div class="text-sm font-bold text-emerald-400">
                          {prod_icon} {Float.round(prod_rate * 168.0, 0)}
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
                <!-- Energy stats for generators (static balance, not flowing resource) -->
                <%= if @selected in ["power_plant", "nuclear_reactor"] do %>
                  <div class="bg-gray-800/60 rounded-xl p-3 mb-4 border border-gray-700/60">
                    <h4 class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                      {gettext("Energy Production")}
                    </h4>

                    <div class="grid grid-cols-2 gap-3 mb-3">
                      <div class="bg-gray-900/60 rounded-lg p-2.5 text-center">
                        <div class="text-[10px] text-gray-500 mb-1">
                          {gettext("This building produces")}
                        </div>

                        <div class="text-xl font-bold text-yellow-400">
                          ⚡ {round(sel_energy_prod)}
                        </div>

                        <div class="text-[10px] text-gray-500 mt-0.5">
                          {gettext("energy at current level")}
                        </div>
                      </div>

                      <div class="bg-gray-900/60 rounded-lg p-2.5 text-center">
                        <div class="text-[10px] text-gray-500 mb-1">{gettext("Planet Balance")}</div>

                        <div class={[
                          "text-xl font-bold",
                          if(@rates.energy_balance >= 0, do: "text-emerald-400", else: "text-red-400")
                        ]}>
                          {if @rates.energy_balance >= 0, do: "+", else: ""}{round(
                            @rates.energy_balance
                          )}
                        </div>

                        <div class="text-[10px] text-gray-500 mt-0.5">
                          {round(@rates.efficiency * 100)}% {gettext("efficiency")}
                        </div>
                      </div>
                    </div>

                    <div class="bg-gray-900/60 rounded-lg px-3 py-2 flex items-center justify-between text-xs">
                      <div>
                        <span class="text-emerald-400 font-semibold">
                          +{round(@rates.energy_produce)}
                        </span>
                        <span class="text-gray-500 ml-1">{gettext("produced")}</span>
                      </div>

                      <div>
                        <span class="text-red-400 font-semibold">
                          -{round(@rates.energy_consume)}
                        </span>
                        <span class="text-gray-500 ml-1">{gettext("consumed")}</span>
                      </div>
                    </div>
                  </div>
                <% end %>
                <!-- Upgrade section -->
                <div class="border-t border-gray-800 pt-4">
                  <h4 class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                    {if sel_level == 0,
                      do: gettext("Initial Construction"),
                      else: "#{gettext("Upgrade → Level")} #{sel_next}"}
                  </h4>

                  <%= if sel_constructing do %>
                    <div class="flex items-center justify-between bg-yellow-950/40 rounded-xl px-4 py-3 border border-yellow-800/50">
                      <div>
                        <p class="text-yellow-300 text-sm font-semibold">
                          ⏳ {gettext("Construction in progress")}
                        </p>

                        <p class="text-yellow-600 text-xs mt-0.5">
                          {gettext("Upgrading to level")} {sel_next}
                        </p>
                      </div>

                      <div class="text-right">
                        <p class="text-yellow-200 text-2xl font-mono font-bold tabular-nums">
                          {format_duration(sel_rem)}
                        </p>

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
                            else: "text-red-400 font-semibold"
                          )
                        ]}>
                          {resource_label(resource)}: {amount}
                        </span>
                      <% end %>
                    </div>

                    <%= if @any_constructing do %>
                      <p class="text-yellow-500 text-xs">
                        ⚠ {gettext("A construction is already in progress on this planet.")}
                      </p>
                    <% else %>
                      <button
                        phx-click="build"
                        phx-value-type={@selected}
                        disabled={not sel_can}
                        class={[
                          "py-2 px-6 rounded-lg text-sm font-bold transition",
                          if(sel_can,
                            do: "bg-cyan-700 hover:bg-cyan-600 text-white cursor-pointer",
                            else: "bg-gray-800 text-gray-600 cursor-not-allowed"
                          )
                        ]}
                      >
                        {if sel_level == 0,
                          do: gettext("Build"),
                          else: "#{gettext("Upgrade → Level")} #{sel_next}"}
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
                <%= if @selected == "spaceport" do %>
                  <% no_fleet = @spaceport_fleets == []
                  can_build = not no_fleet and @selected_fleet_id not in [nil, ""] %>
                  <div class="flex flex-1 overflow-hidden">
                    <!-- ══ LEFT: Build Queue ══ -->
                    <div class="w-52 shrink-0 flex flex-col border-r border-gray-800 overflow-hidden bg-gray-950/30">
                      <div class="px-3 pt-3 pb-2 border-b border-gray-800 shrink-0">
                        <h3 class="text-[11px] font-bold uppercase tracking-widest text-gray-500">
                          {gettext("Build Queue")}
                        </h3>
                      </div>

                      <div class="flex-1 overflow-y-auto flex flex-col gap-2 px-2 py-2">
                        <%= if @shipyard_queue_items == [] do %>
                          <div class="flex flex-col items-center justify-center h-full text-center gap-2 py-8">
                            <span class="text-3xl opacity-20">🚀</span>
                            <p class="text-xs text-gray-600">{gettext("Queue is empty")}</p>
                          </div>
                        <% else %>
                          <%= for {item, idx} <- Enum.with_index(@shipyard_queue_items) do %>
                            <% is_building = item.status == "building" and item.finish_at != nil %> <% rem_s =
                              if is_building,
                                do: max(0, DateTime.diff(item.finish_at, @now, :second)),
                                else: 0 %> <% total_s =
                              if is_building, do: max(1, item.build_seconds), else: 1 %> <% pct =
                              if is_building, do: trunc((1 - rem_s / total_s) * 100), else: 0 %>
                            <div class={[
                              "relative rounded-xl p-2.5 border overflow-hidden",
                              if(is_building,
                                do: "border-emerald-800/60 bg-emerald-950/30",
                                else: "border-gray-700 bg-gray-800/40"
                              )
                            ]}>
                              <div class="flex items-start gap-2">
                                <div class={[
                                  "w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold text-white shrink-0 mt-0.5",
                                  if(is_building, do: "bg-emerald-600", else: "bg-pink-600")
                                ]}>
                                  {idx + 1}
                                </div>

                                <div class="min-w-0 flex-1">
                                  <p class="text-[12px] font-semibold text-white leading-tight truncate">
                                    {ship_name(item.ship_type)}
                                  </p>

                                  <p class="text-[11px] text-gray-400">×{item.quantity}</p>

                                  <p class="text-[10px] text-gray-500 truncate">
                                    → {item.fleet.name}
                                  </p>
                                </div>
                              </div>

                              <%= if is_building do %>
                                <div class="mt-2">
                                  <div class="flex items-center justify-between text-[10px] mb-1">
                                    <span class="text-emerald-400 font-mono font-semibold">
                                      {format_duration(rem_s)}
                                    </span>
                                    <span class="text-gray-500">{pct}%</span>
                                  </div>

                                  <div class="h-1.5 rounded-full bg-gray-700 overflow-hidden">
                                    <div
                                      class="h-full bg-emerald-500 rounded-full transition-all duration-1000"
                                      style={"width: #{pct}%"}
                                    />
                                  </div>
                                </div>
                              <% else %>
                                <p class="text-[10px] text-gray-600 italic mt-1">
                                  {gettext("Position")} #{item.queue_position}
                                </p>
                              <% end %>
                            </div>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                    <!-- ══ CENTER: Ship Catalog ══ -->
                    <div class="flex-1 overflow-y-auto flex flex-col">
                      <%= if no_fleet do %>
                        <div class="px-4 py-3 border-b border-amber-900/40 bg-amber-950/20 shrink-0">
                          <p class="text-amber-400 text-xs font-medium">
                            ⚠ {gettext("No fleets at this planet. Create a fleet here first.")}
                          </p>

                          <.link
                            navigate={~p"/fleet"}
                            class="mt-2 inline-flex rounded-lg bg-cyan-700 px-3 py-1.5 text-xs font-semibold text-white hover:bg-cyan-600 transition"
                          >
                            {gettext("Open Fleet command")}
                          </.link>
                        </div>
                      <% end %>

                      <%= if @shipyard_error do %>
                        <div class="mx-3 mt-2 mb-1 rounded-lg border border-red-700 bg-red-950/40 px-3 py-2 text-xs text-red-300 shrink-0">
                          {@shipyard_error}
                        </div>
                      <% end %>

                      <%= if @shipyard_notice do %>
                        <div class="mx-3 mt-2 mb-1 rounded-lg border border-emerald-700 bg-emerald-950/40 px-3 py-2 text-xs text-emerald-300 shrink-0">
                          {@shipyard_notice}
                        </div>
                      <% end %>

                      <div class="flex flex-col divide-y divide-gray-800/60">
                        <%= for ship <- @ship_catalog do %>
                          <% qty_in_order = Map.get(@build_order, ship.type, 0) %> <% tier_icon =
                            case ship.tier do
                              1 -> "🚀"
                              2 -> "⚔️"
                              3 -> "🛸"
                              _ -> "💀"
                            end %> <% tier_color =
                            case ship.tier do
                              1 -> "text-cyan-400"
                              2 -> "text-amber-400"
                              3 -> "text-red-400"
                              _ -> "text-purple-400"
                            end %>
                          <form
                            phx-submit="add_to_build_order"
                            class="flex items-center gap-3 px-4 py-3 hover:bg-gray-800/30 transition"
                          >
                            <input type="hidden" name="ship_type" value={ship.type} />
                            <!-- Tier icon -->
                            <div class="relative w-9 h-9 shrink-0 rounded-lg bg-gray-900/80 border border-gray-700/60 flex items-center justify-center text-base">
                              <span class={tier_color}>{tier_icon}</span>
                              <%= if qty_in_order > 0 do %>
                                <div class="absolute -top-1.5 -right-1.5 min-w-[16px] h-4 rounded-full bg-pink-600 flex items-center justify-center text-[9px] font-bold text-white px-0.5">
                                  {qty_in_order}
                                </div>
                              <% end %>
                            </div>
                            <!-- Ship info -->
                            <div class="flex-1 min-w-0">
                              <div class="flex items-baseline gap-2 flex-wrap">
                                <button
                                  type="button"
                                  phx-click="show_ship_details"
                                  phx-value-ship_type={ship.type}
                                  data-unit-detail={"ship-#{ship.type}"}
                                  class="text-left text-sm font-semibold text-white hover:text-cyan-300 transition"
                                >
                                  {translate_dynamic(ship.name)}
                                </button>
                                <span class="text-xs text-gray-500 shrink-0">
                                  ⏱ {format_duration(ship.build_time_seconds)}
                                </span>
                              </div>

                              <p
                                class="text-xs text-gray-400 mt-1 leading-snug"
                                style="-webkit-line-clamp: 2; -webkit-box-orient: vertical; display: -webkit-box; overflow: hidden;"
                              >
                                {translate_dynamic(ship.description)}
                              </p>

                              <div class="flex items-center gap-3 mt-0.5 flex-wrap">
                                <span class="text-xs text-amber-400">
                                  ⛏ {format_resource(ship.cost.raw_materials * 1.0)}
                                </span>
                                <span class="text-xs text-blue-400">
                                  💾 {format_resource(ship.cost.microchips * 1.0)}
                                </span>
                                <span class="text-xs text-cyan-400">
                                  💧 {format_resource(ship.cost.hydrogen * 1.0)}
                                </span>
                                <span class="text-xs text-gray-500">
                                  ⚔ {ship.attack} · 🛡 {ship.hull}
                                </span>
                              </div>
                            </div>
                            <!-- Qty + Add -->
                            <div class="flex items-center gap-1.5 shrink-0">
                              <input
                                type="number"
                                name="quantity"
                                min="1"
                                value="1"
                                disabled={no_fleet}
                                class="w-14 rounded-lg border border-gray-700 bg-gray-900 px-2 py-1.5 text-sm text-white text-center focus:border-pink-500 focus:outline-none [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                              />
                              <button
                                type="submit"
                                disabled={no_fleet}
                                class={[
                                  "rounded-lg px-3 py-1.5 text-sm font-semibold transition",
                                  if(no_fleet,
                                    do: "bg-gray-800 text-gray-600 cursor-not-allowed",
                                    else: "bg-pink-600 hover:bg-pink-500 text-white cursor-pointer"
                                  )
                                ]}
                              >
                                {gettext("Add")}
                              </button>
                            </div>
                          </form>
                        <% end %>
                      </div>
                    </div>
                    <!-- ══ RIGHT: Build Summary ══ -->
                    <div class="w-72 shrink-0 flex flex-col border-l border-gray-800 overflow-hidden bg-gray-950/30">
                      <div class="px-3 pt-3 pb-2 border-b border-gray-800 shrink-0">
                        <h3 class="text-xs font-bold uppercase tracking-widest text-gray-500 mb-2">
                          {gettext("Build Summary")}
                        </h3>

                        <p class="text-xs text-gray-600 mb-1">{gettext("Target Fleet:")}</p>

                        <form phx-change="set_target_fleet">
                          <select
                            name="fleet_id"
                            class="w-full rounded-lg border border-gray-700 bg-gray-900 px-2 py-1.5 text-sm text-white focus:border-cyan-500 focus:outline-none"
                          >
                            <option value="">{gettext("— select fleet —")}</option>

                            <%= for fleet <- @spaceport_fleets do %>
                              <option
                                value={fleet.id}
                                selected={to_string(fleet.id) == @selected_fleet_id}
                              >
                                {fleet.name}
                              </option>
                            <% end %>
                          </select>
                        </form>
                      </div>
                      <!-- Staged orders -->
                      <div class="flex-1 overflow-y-auto p-2 flex flex-col gap-1.5">
                        <%= if Enum.all?(@build_order, fn {_, q} -> q == 0 end) or map_size(@build_order) == 0 do %>
                          <div class="flex flex-col items-center justify-center h-full text-center gap-2 py-8">
                            <p class="text-xs text-gray-600">{gettext("No ships staged yet.")}</p>

                            <p class="text-[10px] text-gray-700">
                              {gettext("Add ships from the list.")}
                            </p>
                          </div>
                        <% else %>
                          <%= for ship <- @ship_catalog, Map.get(@build_order, ship.type, 0) > 0 do %>
                            <% qty = Map.get(@build_order, ship.type, 0) %> <% row_raw_materials =
                              ship.cost.raw_materials * qty * 1.0 %> <% row_microchips =
                              ship.cost.microchips * qty * 1.0 %> <% row_hydrogen =
                              ship.cost.hydrogen * qty * 1.0 %>
                            <div class="rounded-lg border border-gray-700 bg-gray-800/40 p-2">
                              <div class="flex items-center justify-between gap-1">
                                <span class="text-xs font-semibold text-white leading-tight flex-1 pr-1 truncate">
                                  {translate_dynamic(ship.name)}
                                </span>
                                <div class="flex items-center gap-0.5 shrink-0">
                                  <button
                                    phx-click="adjust_build_order"
                                    phx-value-ship_type={ship.type}
                                    phx-value-delta="-1"
                                    class="w-5 h-5 rounded bg-gray-700 hover:bg-gray-600 text-white text-xs flex items-center justify-center leading-none"
                                  >
                                    −
                                  </button>
                                  <span class="w-6 text-center text-xs font-mono text-white">
                                    {qty}
                                  </span>
                                  <button
                                    phx-click="adjust_build_order"
                                    phx-value-ship_type={ship.type}
                                    phx-value-delta="1"
                                    class="w-5 h-5 rounded bg-gray-700 hover:bg-gray-600 text-white text-xs flex items-center justify-center leading-none"
                                  >
                                    +
                                  </button>
                                </div>
                              </div>

                              <div class="flex items-center justify-between mt-1 text-xs">
                                <span class="text-gray-500">
                                  ⏱ {format_duration(ship.build_time_seconds * qty)}
                                </span>
                              </div>

                              <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs">
                                <span class="text-amber-500">
                                  ⛏ {format_resource(row_raw_materials)}
                                </span>
                                <span class="text-blue-400">💾 {format_resource(row_microchips)}</span>
                                <span class="text-cyan-400">💧 {format_resource(row_hydrogen)}</span>
                              </div>
                            </div>
                          <% end %>
                        <% end %>
                      </div>
                      <!-- Totals + submit -->
                      <% total_items = Enum.reduce(@build_order, 0, fn {_, q}, acc -> acc + q end)

                      total_time_s =
                        Enum.reduce(@build_order, 0, fn {type, qty}, acc ->
                          ship = Enum.find(@ship_catalog, &(&1.type == type))
                          if ship, do: acc + ship.build_time_seconds * qty, else: acc
                        end)

                      total_rm =
                        Enum.reduce(@build_order, 0, fn {type, qty}, acc ->
                          ship = Enum.find(@ship_catalog, &(&1.type == type))
                          if ship, do: acc + ship.cost.raw_materials * qty, else: acc
                        end)

                      total_mc =
                        Enum.reduce(@build_order, 0, fn {type, qty}, acc ->
                          ship = Enum.find(@ship_catalog, &(&1.type == type))
                          if ship, do: acc + ship.cost.microchips * qty, else: acc
                        end)

                      total_h2 =
                        Enum.reduce(@build_order, 0, fn {type, qty}, acc ->
                          ship = Enum.find(@ship_catalog, &(&1.type == type))
                          if ship, do: acc + ship.cost.hydrogen * qty, else: acc
                        end) %>
                      <div class="border-t border-gray-800 p-3 shrink-0 flex flex-col gap-2">
                        <div class="grid grid-cols-2 gap-y-1 text-xs">
                          <div class="text-gray-500">{gettext("Total Items:")}</div>

                          <div class="text-white font-semibold text-right">{total_items}</div>

                          <div class="text-gray-500">{gettext("Total Time:")}</div>

                          <div class="text-white font-semibold text-right">
                            {format_duration(total_time_s)}
                          </div>
                        </div>

                        <%= if total_items > 0 do %>
                          <div class="bg-gray-900/60 rounded-lg px-2 py-1.5 text-xs flex flex-col gap-0.5">
                            <div class="flex justify-between">
                              <span class="text-amber-400">⛏ Mat.</span>
                              <span class="text-amber-300">{format_resource(total_rm * 1.0)}</span>
                            </div>

                            <div class="flex justify-between">
                              <span class="text-blue-400">💾 Chips</span>
                              <span class="text-blue-300">{format_resource(total_mc * 1.0)}</span>
                            </div>

                            <div class="flex justify-between">
                              <span class="text-cyan-400">💧 H₂</span>
                              <span class="text-cyan-300">{format_resource(total_h2 * 1.0)}</span>
                            </div>
                          </div>
                        <% end %>

                        <button
                          phx-click="submit_build_order"
                          disabled={not can_build or total_items == 0}
                          class={[
                            "w-full rounded-lg py-2 text-sm font-bold uppercase tracking-wider transition",
                            if(can_build and total_items > 0,
                              do: "bg-pink-600 hover:bg-pink-500 text-white cursor-pointer",
                              else: "bg-gray-800 text-gray-600 cursor-not-allowed"
                            )
                          ]}
                        >
                          {gettext("Build Ships")}
                        </button>
                        <%= if @dev_tools_enabled do %>
                          <button
                            phx-click="grant_test_resources"
                            class="w-full rounded-lg py-2 text-[11px] font-semibold uppercase tracking-wider transition bg-cyan-700/80 hover:bg-cyan-600 text-white"
                          >
                            {gettext("Add Test Resources")}
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <%= if @selected == "defense_center" do %>
                    <% center_ready = sel_level >= 1 %>
                    <div class="flex flex-1 overflow-hidden">
                      <div class="w-56 shrink-0 flex flex-col border-r border-gray-800 overflow-hidden bg-gray-950/30">
                        <div class="px-3 pt-3 pb-2 border-b border-gray-800 shrink-0">
                          <h3 class="text-[11px] font-bold uppercase tracking-widest text-gray-500">
                            {gettext("Defense Queue")}
                          </h3>
                        </div>

                        <div class="flex-1 overflow-y-auto flex flex-col gap-2 px-2 py-2">
                          <%= if @defense_queue_items == [] do %>
                            <div class="flex flex-col items-center justify-center h-full text-center gap-2 py-8">
                              <span class="text-2xl font-bold opacity-20">DEF</span>
                              <p class="text-xs text-gray-600">{gettext("Queue is empty")}</p>
                            </div>
                          <% else %>
                            <%= for {item, idx} <- Enum.with_index(@defense_queue_items) do %>
                              <% is_building = item.status == "building" and item.finish_at != nil %> <% rem_s =
                                if is_building,
                                  do: max(0, DateTime.diff(item.finish_at, @now, :second)),
                                  else: 0 %> <% total_s =
                                if is_building, do: max(1, item.build_seconds), else: 1 %> <% pct =
                                if is_building, do: trunc((1 - rem_s / total_s) * 100), else: 0 %>
                              <div class={[
                                "rounded-xl p-2.5 border overflow-hidden",
                                if(is_building,
                                  do: "border-cyan-800/60 bg-cyan-950/30",
                                  else: "border-gray-700 bg-gray-800/40"
                                )
                              ]}>
                                <div class="flex items-start gap-2">
                                  <div class={[
                                    "w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold text-white shrink-0 mt-0.5",
                                    if(is_building, do: "bg-cyan-600", else: "bg-indigo-600")
                                  ]}>
                                    {idx + 1}
                                  </div>
                                  <div class="min-w-0 flex-1">
                                    <p class="text-[12px] font-semibold text-white leading-tight truncate">
                                      {defense_name(item.defense_type)}
                                    </p>
                                    <p class="text-[11px] text-gray-400">x{item.quantity}</p>
                                  </div>
                                </div>

                                <%= if is_building do %>
                                  <div class="mt-2">
                                    <div class="flex items-center justify-between text-[10px] mb-1">
                                      <span class="text-cyan-400 font-mono font-semibold">
                                        {format_duration(rem_s)}
                                      </span>
                                      <span class="text-gray-500">{pct}%</span>
                                    </div>
                                    <div class="h-1.5 rounded-full bg-gray-700 overflow-hidden">
                                      <div
                                        class="h-full bg-cyan-500 rounded-full transition-all duration-1000"
                                        style={"width: #{pct}%"}
                                      />
                                    </div>
                                  </div>
                                <% else %>
                                  <p class="text-[10px] text-gray-600 italic mt-1">
                                    {gettext("Position")} #{item.queue_position}
                                  </p>
                                <% end %>
                              </div>
                            <% end %>
                          <% end %>
                        </div>
                      </div>

                      <div class="flex-1 overflow-y-auto flex flex-col">
                        <%= if not center_ready do %>
                          <div class="px-4 py-3 border-b border-amber-900/40 bg-amber-950/20 shrink-0">
                            <p class="text-amber-400 text-xs font-medium">
                              {gettext("Defense Center level 1 is required to build defenses.")}
                            </p>
                          </div>
                        <% end %>

                        <%= if @defense_error do %>
                          <div class="mx-3 mt-2 mb-1 rounded-lg border border-red-700 bg-red-950/40 px-3 py-2 text-xs text-red-300 shrink-0">
                            {@defense_error}
                          </div>
                        <% end %>

                        <%= if @defense_notice do %>
                          <div class="mx-3 mt-2 mb-1 rounded-lg border border-emerald-700 bg-emerald-950/40 px-3 py-2 text-xs text-emerald-300 shrink-0">
                            {@defense_notice}
                          </div>
                        <% end %>

                        <div class="flex flex-col divide-y divide-gray-800/60">
                          <%= for defense <- @defense_catalog do %>
                            <% qty_in_order = Map.get(@defense_order, defense.type, 0) %>
                            <% owned_qty = defense_quantity(@planet_defenses, defense.type) %>
                            <% queued_qty =
                              queued_defense_quantity(@defense_queue_items, defense.type) %>
                            <% remaining_limit =
                              defense_remaining_limit(defense, owned_qty, queued_qty, qty_in_order) %>
                            <% limit_reached = remaining_limit == 0 %>
                            <form
                              phx-submit="add_to_defense_order"
                              class="flex items-center gap-3 px-4 py-3 hover:bg-gray-800/30 transition"
                            >
                              <input type="hidden" name="defense_type" value={defense.type} />
                              <div class="relative w-9 h-9 shrink-0 rounded-lg bg-gray-900/80 border border-gray-700/60 flex items-center justify-center text-[11px] font-bold text-cyan-300">
                                T{defense.tier}
                                <%= if qty_in_order > 0 do %>
                                  <div class="absolute -top-1.5 -right-1.5 min-w-[16px] h-4 rounded-full bg-cyan-600 flex items-center justify-center text-[9px] font-bold text-white px-0.5">
                                    {qty_in_order}
                                  </div>
                                <% end %>
                              </div>

                              <div class="flex-1 min-w-0">
                                <div class="flex items-baseline gap-2 flex-wrap">
                                  <button
                                    type="button"
                                    phx-click="show_defense_details"
                                    phx-value-defense_type={defense.type}
                                    data-unit-detail={"defense-#{defense.type}"}
                                    class="text-left text-sm font-semibold text-white hover:text-cyan-300 transition"
                                  >
                                    {translate_dynamic(defense.name)}
                                  </button>
                                  <span class="text-xs text-gray-500 shrink-0">
                                    {gettext("Owned")}: {owned_qty}
                                  </span>
                                  <span class="text-xs text-gray-500 shrink-0">
                                    {gettext("Queued")}: {queued_qty}
                                  </span>
                                  <%= if Map.has_key?(defense, :max_per_planet) do %>
                                    <span class="text-xs text-amber-400 shrink-0">
                                      {gettext("Limit")}: {defense.max_per_planet}
                                    </span>
                                    <span class="text-xs text-cyan-400 shrink-0">
                                      {gettext("Available")}: {remaining_limit}
                                    </span>
                                  <% end %>
                                </div>

                                <p
                                  class="text-xs text-gray-400 mt-1 leading-snug"
                                  style="-webkit-line-clamp: 2; -webkit-box-orient: vertical; display: -webkit-box; overflow: hidden;"
                                >
                                  {translate_dynamic(defense.description)}
                                </p>

                                <div class="flex items-center gap-3 mt-0.5 flex-wrap">
                                  <span class="text-xs text-amber-400">
                                    Mat. {format_resource(defense.cost.raw_materials * 1.0)}
                                  </span>
                                  <span class="text-xs text-blue-400">
                                    {gettext("Chips")} {format_resource(defense.cost.microchips * 1.0)}
                                  </span>
                                  <span class="text-xs text-cyan-400">
                                    H2 {format_resource(defense.cost.hydrogen * 1.0)}
                                  </span>
                                  <span class="text-xs text-gray-500">
                                    ATK {defense.attack} / HP {defense.hull}
                                  </span>
                                </div>
                              </div>

                              <div class="flex items-center gap-1.5 shrink-0">
                                <input
                                  type="number"
                                  name="quantity"
                                  min="1"
                                  max={if is_integer(remaining_limit), do: remaining_limit, else: nil}
                                  value="1"
                                  disabled={not center_ready or limit_reached}
                                  class="w-14 rounded-lg border border-gray-700 bg-gray-900 px-2 py-1.5 text-sm text-white text-center focus:border-cyan-500 focus:outline-none disabled:text-gray-600 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                                />
                                <button
                                  type="submit"
                                  disabled={not center_ready or limit_reached}
                                  class={[
                                    "rounded-lg px-3 py-1.5 text-sm font-semibold transition",
                                    if(center_ready and not limit_reached,
                                      do: "bg-cyan-600 hover:bg-cyan-500 text-white cursor-pointer",
                                      else: "bg-gray-800 text-gray-600 cursor-not-allowed"
                                    )
                                  ]}
                                >
                                  {gettext("Add")}
                                </button>
                              </div>
                            </form>
                          <% end %>
                        </div>
                      </div>

                      <div class="w-72 shrink-0 flex flex-col border-l border-gray-800 overflow-hidden bg-gray-950/30">
                        <div class="px-3 pt-3 pb-2 border-b border-gray-800 shrink-0">
                          <h3 class="text-xs font-bold uppercase tracking-widest text-gray-500">
                            {gettext("Defense Summary")}
                          </h3>
                        </div>

                        <div class="flex-1 overflow-y-auto p-2 flex flex-col gap-1.5">
                          <%= if Enum.all?(@defense_order, fn {_, q} -> q == 0 end) or map_size(@defense_order) == 0 do %>
                            <div class="flex flex-col items-center justify-center h-full text-center gap-2 py-8">
                              <p class="text-xs text-gray-600">
                                {gettext("No defenses staged yet.")}
                              </p>
                              <p class="text-[10px] text-gray-700">
                                {gettext("Add defenses from the list.")}
                              </p>
                            </div>
                          <% else %>
                            <%= for defense <- @defense_catalog, Map.get(@defense_order, defense.type, 0) > 0 do %>
                              <% qty = Map.get(@defense_order, defense.type, 0) %>
                              <% owned_qty = defense_quantity(@planet_defenses, defense.type) %>
                              <% queued_qty =
                                queued_defense_quantity(@defense_queue_items, defense.type) %>
                              <% remaining_limit =
                                defense_remaining_limit(defense, owned_qty, queued_qty, qty) %>
                              <% can_increment = remaining_limit != 0 %>
                              <div class="rounded-lg border border-gray-700 bg-gray-800/40 p-2">
                                <div class="flex items-center justify-between gap-1">
                                  <span class="text-xs font-semibold text-white leading-tight flex-1 pr-1 truncate">
                                    {translate_dynamic(defense.name)}
                                  </span>
                                  <div class="flex items-center gap-0.5 shrink-0">
                                    <button
                                      phx-click="adjust_defense_order"
                                      phx-value-defense_type={defense.type}
                                      phx-value-delta="-1"
                                      class="w-5 h-5 rounded bg-gray-700 hover:bg-gray-600 text-white text-xs flex items-center justify-center leading-none"
                                    >
                                      -
                                    </button>
                                    <span class="w-6 text-center text-xs font-mono text-white">
                                      {qty}
                                    </span>
                                    <button
                                      phx-click="adjust_defense_order"
                                      phx-value-defense_type={defense.type}
                                      phx-value-delta="1"
                                      disabled={not can_increment}
                                      class={[
                                        "w-5 h-5 rounded text-xs flex items-center justify-center leading-none",
                                        if(can_increment,
                                          do: "bg-gray-700 hover:bg-gray-600 text-white",
                                          else: "bg-gray-800 text-gray-600 cursor-not-allowed"
                                        )
                                      ]}
                                    >
                                      +
                                    </button>
                                  </div>
                                </div>
                                <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs">
                                  <span class="text-gray-500">
                                    {format_duration(defense.build_time_seconds * qty)}
                                  </span>
                                  <span class="text-amber-500">
                                    Mat. {format_resource(defense.cost.raw_materials * qty * 1.0)}
                                  </span>
                                  <span class="text-blue-400">
                                    {gettext("Chips")} {format_resource(
                                      defense.cost.microchips * qty * 1.0
                                    )}
                                  </span>
                                  <span class="text-cyan-400">
                                    H2 {format_resource(defense.cost.hydrogen * qty * 1.0)}
                                  </span>
                                </div>
                              </div>
                            <% end %>
                          <% end %>
                        </div>

                        <% total_defense_items =
                          Enum.reduce(@defense_order, 0, fn {_, q}, acc -> acc + q end)

                        total_defense_time_s =
                          Enum.reduce(@defense_order, 0, fn {type, qty}, acc ->
                            defense = Enum.find(@defense_catalog, &(&1.type == type))
                            if defense, do: acc + defense.build_time_seconds * qty, else: acc
                          end) %>
                        <div class="border-t border-gray-800 p-3 shrink-0 flex flex-col gap-2">
                          <div class="grid grid-cols-2 gap-y-1 text-xs">
                            <div class="text-gray-500">{gettext("Total Items:")}</div>
                            <div class="text-white font-semibold text-right">
                              {total_defense_items}
                            </div>
                            <div class="text-gray-500">{gettext("Total Time:")}</div>
                            <div class="text-white font-semibold text-right">
                              {format_duration(total_defense_time_s)}
                            </div>
                          </div>

                          <button
                            phx-click="submit_defense_order"
                            disabled={not center_ready or total_defense_items == 0}
                            class={[
                              "w-full rounded-lg py-2 text-sm font-bold uppercase tracking-wider transition",
                              if(center_ready and total_defense_items > 0,
                                do: "bg-cyan-600 hover:bg-cyan-500 text-white cursor-pointer",
                                else: "bg-gray-800 text-gray-600 cursor-not-allowed"
                              )
                            ]}
                          >
                            {gettext("Build Defenses")}
                          </button>
                          <%= if @dev_tools_enabled do %>
                            <button
                              phx-click="grant_test_resources"
                              class="w-full rounded-lg py-2 text-[11px] font-semibold uppercase tracking-wider transition bg-cyan-700/80 hover:bg-cyan-600 text-white"
                            >
                              {gettext("Add Test Resources")}
                            </button>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <div class="flex flex-col items-center justify-center h-36 text-center gap-2">
                      <span class="text-4xl">🔧</span>
                      <p class="text-gray-500 text-sm">
                        {gettext("Specific structure information coming soon.")}
                      </p>
                    </div>
                  <% end %>
                <% end %>
              <% end %>
              <!-- ── TAB: Especialización ── -->
              <%= if @selected_tab == "specialization" do %>
                <div class="flex flex-col items-center justify-center h-36 text-center gap-2">
                  <span class="text-4xl">⭐</span>
                  <p class="text-gray-500 text-sm">{gettext("Specialization system coming soon.")}</p>
                </div>
              <% end %>
            </div>
            <%= if @unit_detail do %>
              <div class="absolute inset-0 z-30 flex items-center justify-center bg-black/80 p-5 backdrop-blur-sm">
                <div
                  class="absolute inset-0"
                  phx-click="close_unit_details"
                />
                <div class="relative z-10 w-full max-w-2xl overflow-hidden rounded-2xl border border-cyan-900/70 bg-gray-950 shadow-2xl">
                  <div class="grid gap-0 md:grid-cols-[220px_minmax(0,1fr)]">
                    <div class="relative min-h-[220px] bg-gray-900">
                      <img
                        src={@unit_detail.image_path}
                        class="absolute inset-0 h-full w-full object-contain p-6"
                        draggable="false"
                      />
                      <div class="absolute inset-0 bg-gradient-to-t from-gray-950 via-transparent to-cyan-950/20" />
                    </div>

                    <div class="flex max-h-[72vh] flex-col overflow-y-auto p-5">
                      <div class="flex items-start justify-between gap-4">
                        <div>
                          <p class="text-xs font-bold uppercase tracking-widest text-cyan-400">
                            {gettext("Details")}
                          </p>
                          <h3 class="mt-1 text-2xl font-bold leading-tight text-white">
                            {translate_dynamic(@unit_detail.name)}
                          </h3>
                        </div>

                        <button
                          phx-click="close_unit_details"
                          class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gray-900 text-gray-400 transition hover:bg-gray-800 hover:text-white"
                        >
                          x
                        </button>
                      </div>

                      <p class="mt-4 text-sm leading-relaxed text-gray-300">
                        {translate_dynamic(@unit_detail.description)}
                      </p>

                      <div class="mt-5 grid grid-cols-2 gap-2 sm:grid-cols-3">
                        <%= for {label, value} <- @unit_detail.stats do %>
                          <div class="rounded-lg border border-gray-800 bg-gray-900/70 px-3 py-2">
                            <div class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">
                              {label}
                            </div>
                            <div class="mt-1 break-words text-sm font-semibold text-gray-100">
                              {value}
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
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
          else: "text-gray-500 border-transparent hover:text-gray-300 hover:border-gray-600"
        )
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

    first_fleet_id =
      case socket.assigns.spaceport_fleets do
        [f | _] -> to_string(f.id)
        [] -> nil
      end

    {:noreply,
     assign(socket,
       selected: selected,
       selected_tab: "info",
       error: nil,
       shipyard_error: nil,
       shipyard_notice: nil,
       build_order: %{},
       defense_error: nil,
       defense_notice: nil,
       defense_order: %{},
       selected_unit_details: nil,
       selected_fleet_id: first_fleet_id
     )}
  end

  def handle_event("close_panel", _params, socket) do
    {:noreply,
     assign(socket,
       selected: nil,
       error: nil,
       shipyard_error: nil,
       shipyard_notice: nil,
       build_order: %{},
       defense_error: nil,
       defense_notice: nil,
       defense_order: %{},
       selected_unit_details: nil
     )}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  def handle_event("show_ship_details", %{"ship_type" => ship_type}, socket) do
    {:noreply, assign(socket, :selected_unit_details, %{kind: "ship", type: ship_type})}
  end

  def handle_event("show_defense_details", %{"defense_type" => defense_type}, socket) do
    {:noreply, assign(socket, :selected_unit_details, %{kind: "defense", type: defense_type})}
  end

  def handle_event("close_unit_details", _params, socket) do
    {:noreply, assign(socket, :selected_unit_details, nil)}
  end

  def handle_event("toggle_user_menu", _params, socket) do
    {:noreply, assign(socket, :show_user_menu, !socket.assigns.show_user_menu)}
  end

  def handle_event("build", %{"type" => building_type}, socket) do
    planet_id = socket.assigns.planet.id
    current_user_id = socket.assigns.current_user.id

    case Planets.start_construction_for_user(planet_id, current_user_id, building_type) do
      {:ok, _building} ->
        {planet, buildings, rates, display, now} = load_planet_state(planet_id, current_user_id)
        shipyard = Fleets.shipyard_panel_for_user_planet(planet_id, current_user_id)
        defense_panel = Defenses.defense_panel_for_user_planet(planet_id, current_user_id)

        {:noreply,
         socket
         |> assign(:planet, planet)
         |> assign(:buildings, buildings)
         |> assign(:rates, rates)
         |> assign(:display, display)
         |> assign(:now, now)
         |> assign(:spaceport_fleets, shipyard.fleets)
         |> assign(:shipyard_queue_items, shipyard.queue_items)
         |> assign(:ship_catalog, shipyard.ship_catalog)
         |> assign(:planet_defenses, defense_panel.defenses)
         |> assign(:defense_queue_items, defense_panel.queue_items)
         |> assign(:defense_catalog, defense_panel.defense_catalog)
         |> assign(:error, nil)}

      {:error, :already_constructing} ->
        {:noreply,
         assign(socket, :error, gettext("A construction is already in progress on this planet."))}

      {:error, :planet_busy} ->
        {:noreply,
         assign(socket, :error, gettext("A construction is already in progress on this planet."))}

      {:error, :insufficient_resources} ->
        {:noreply,
         assign(socket, :error, gettext("Insufficient resources to start construction."))}

      {:error, :not_found} ->
        {:noreply, assign(socket, :error, gettext("Planet not found."))}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("enqueue_ship", params, socket) do
    planet_id = socket.assigns.planet.id
    current_user_id = socket.assigns.current_user.id

    case Fleets.enqueue_ship_construction_for_user(planet_id, current_user_id, params) do
      {:ok, _item} ->
        {planet, buildings, rates, display, now} = load_planet_state(planet_id, current_user_id)
        shipyard = Fleets.shipyard_panel_for_user_planet(planet_id, current_user_id)
        defense_panel = Defenses.defense_panel_for_user_planet(planet_id, current_user_id)

        {:noreply,
         socket
         |> assign(:planet, planet)
         |> assign(:buildings, buildings)
         |> assign(:rates, rates)
         |> assign(:display, display)
         |> assign(:now, now)
         |> assign(:spaceport_fleets, shipyard.fleets)
         |> assign(:shipyard_queue_items, shipyard.queue_items)
         |> assign(:ship_catalog, shipyard.ship_catalog)
         |> assign(:planet_defenses, defense_panel.defenses)
         |> assign(:defense_queue_items, defense_panel.queue_items)
         |> assign(:defense_catalog, defense_panel.defense_catalog)
         |> assign(:shipyard_notice, gettext("Ship construction queued."))
         |> assign(:shipyard_error, nil)}

      {:error, :spaceport_required} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Spaceport level 1 is required to build ships."))}

      {:error, :insufficient_resources} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Insufficient resources to queue ships."))}

      {:error, :fleet_not_found} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Fleet not found."))}

      {:error, :fleet_unavailable} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Selected fleet is not available from this planet."))}

      {:error, :queue_scheduling_failed} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(
           :shipyard_error,
           gettext("Could not schedule ship construction. Please try again.")
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Invalid shipyard request."))}
    end
  end

  # ---------------------------------------------------------------------------
  # Build order events (new shipyard UI)
  # ---------------------------------------------------------------------------

  def handle_event("set_target_fleet", %{"fleet_id" => fleet_id}, socket) do
    {:noreply, assign(socket, :selected_fleet_id, fleet_id)}
  end

  def handle_event(
        "add_to_build_order",
        %{"ship_type" => ship_type, "quantity" => qty_str},
        socket
      ) do
    qty =
      case Integer.parse(qty_str) do
        {n, _} when n > 0 -> n
        _ -> 1
      end

    current = Map.get(socket.assigns.build_order, ship_type, 0)
    new_order = Map.put(socket.assigns.build_order, ship_type, current + qty)
    {:noreply, assign(socket, :build_order, new_order)}
  end

  def handle_event(
        "adjust_build_order",
        %{"ship_type" => ship_type, "delta" => delta_str},
        socket
      ) do
    delta =
      case Integer.parse(delta_str) do
        {n, _} -> n
        :error -> 0
      end

    current = Map.get(socket.assigns.build_order, ship_type, 0)
    new_qty = max(0, current + delta)

    new_order =
      if new_qty == 0,
        do: Map.delete(socket.assigns.build_order, ship_type),
        else: Map.put(socket.assigns.build_order, ship_type, new_qty)

    {:noreply, assign(socket, :build_order, new_order)}
  end

  def handle_event("submit_build_order", _params, socket) do
    %{
      build_order: build_order,
      selected_fleet_id: fleet_id,
      planet: planet,
      current_user: current_user,
      ship_catalog: ship_catalog
    } = socket.assigns

    cond do
      is_nil(fleet_id) or fleet_id == "" ->
        {:noreply,
         assign(socket,
           shipyard_error: gettext("Select a target fleet first."),
           shipyard_notice: nil
         )}

      Enum.all?(build_order, fn {_, q} -> q == 0 end) or map_size(build_order) == 0 ->
        {:noreply,
         assign(socket,
           shipyard_error: gettext("Add ships to the order first."),
           shipyard_notice: nil
         )}

      true ->
        ordered =
          build_order
          |> Enum.filter(fn {_, qty} -> qty > 0 end)
          |> Enum.sort_by(fn {type, _} ->
            ship = Enum.find(ship_catalog, &(&1.type == type))
            if ship, do: {ship.tier, ship.name}, else: {999, type}
          end)

        {ok_count, err_list} =
          Enum.reduce(ordered, {0, []}, fn {ship_type, qty}, {ok_acc, err_acc} ->
            case Fleets.enqueue_ship_construction_for_user(
                   planet.id,
                   current_user.id,
                   %{
                     "fleet_id" => fleet_id,
                     "ship_type" => ship_type,
                     "quantity" => to_string(qty)
                   }
                 ) do
              {:ok, _} -> {ok_acc + 1, err_acc}
              {:error, reason} -> {ok_acc, [reason | err_acc]}
            end
          end)

        {new_planet, buildings, rates, display, now} =
          load_planet_state(planet.id, current_user.id)

        shipyard = Fleets.shipyard_panel_for_user_planet(planet.id, current_user.id)
        defense_panel = Defenses.defense_panel_for_user_planet(planet.id, current_user.id)

        base =
          socket
          |> assign(:build_order, %{})
          |> assign(:planet, new_planet)
          |> assign(:buildings, buildings)
          |> assign(:rates, rates)
          |> assign(:display, display)
          |> assign(:now, now)
          |> assign(:spaceport_fleets, shipyard.fleets)
          |> assign(:shipyard_queue_items, shipyard.queue_items)
          |> assign(:ship_catalog, shipyard.ship_catalog)
          |> assign(:planet_defenses, defense_panel.defenses)
          |> assign(:defense_queue_items, defense_panel.queue_items)
          |> assign(:defense_catalog, defense_panel.defense_catalog)

        if err_list == [] do
          {:noreply,
           assign(base,
             shipyard_notice: gettext("Ships queued successfully!"),
             shipyard_error: nil
           )}
        else
          failed_reasons =
            err_list
            |> Enum.reverse()
            |> Enum.map(&shipyard_error_reason_label/1)
            |> Enum.join(", ")

          msg =
            "#{ok_count} #{gettext("batch(es) queued")}. #{length(err_list)} #{gettext("failed")}: #{failed_reasons}"

          {:noreply, assign(base, shipyard_error: msg, shipyard_notice: nil)}
        end
    end
  end

  def handle_event(
        "add_to_defense_order",
        %{"defense_type" => defense_type, "quantity" => qty_str},
        socket
      ) do
    qty =
      case Integer.parse(qty_str) do
        {n, _} when n > 0 -> n
        _ -> 1
      end

    current = Map.get(socket.assigns.defense_order, defense_type, 0)

    case validate_defense_staging(socket.assigns, defense_type, qty) do
      :ok ->
        new_order = Map.put(socket.assigns.defense_order, defense_type, current + qty)

        {:noreply,
         assign(socket,
           defense_order: new_order,
           defense_error: nil,
           defense_notice: nil
         )}

      {:error, message} ->
        {:noreply, assign(socket, defense_error: message, defense_notice: nil)}
    end
  end

  def handle_event(
        "adjust_defense_order",
        %{"defense_type" => defense_type, "delta" => delta_str},
        socket
      ) do
    delta =
      case Integer.parse(delta_str) do
        {n, _} -> n
        :error -> 0
      end

    current = Map.get(socket.assigns.defense_order, defense_type, 0)

    if delta > 0 do
      case validate_defense_staging(socket.assigns, defense_type, delta) do
        :ok ->
          new_qty = current + delta
          new_order = Map.put(socket.assigns.defense_order, defense_type, new_qty)

          {:noreply,
           assign(socket,
             defense_order: new_order,
             defense_error: nil,
             defense_notice: nil
           )}

        {:error, message} ->
          {:noreply, assign(socket, defense_error: message, defense_notice: nil)}
      end
    else
      new_qty = max(0, current + delta)

      new_order =
        if new_qty == 0,
          do: Map.delete(socket.assigns.defense_order, defense_type),
          else: Map.put(socket.assigns.defense_order, defense_type, new_qty)

      {:noreply, assign(socket, defense_order: new_order, defense_error: nil)}
    end
  end

  def handle_event("submit_defense_order", _params, socket) do
    %{
      defense_order: defense_order,
      planet: planet,
      current_user: current_user,
      defense_catalog: defense_catalog
    } = socket.assigns

    if Enum.all?(defense_order, fn {_, q} -> q == 0 end) or map_size(defense_order) == 0 do
      {:noreply,
       assign(socket,
         defense_error: gettext("Add defenses to the order first."),
         defense_notice: nil
       )}
    else
      ordered =
        defense_order
        |> Enum.filter(fn {_, qty} -> qty > 0 end)
        |> Enum.sort_by(fn {type, _} ->
          defense = Enum.find(defense_catalog, &(&1.type == type))
          if defense, do: {defense.tier, defense.name}, else: {999, type}
        end)

      {ok_count, err_list} =
        Enum.reduce(ordered, {0, []}, fn {defense_type, qty}, {ok_acc, err_acc} ->
          case Defenses.enqueue_defense_construction_for_user(
                 planet.id,
                 current_user.id,
                 %{"defense_type" => defense_type, "quantity" => to_string(qty)}
               ) do
            {:ok, _} -> {ok_acc + 1, err_acc}
            {:error, reason} -> {ok_acc, [reason | err_acc]}
          end
        end)

      {new_planet, buildings, rates, display, now} =
        load_planet_state(planet.id, current_user.id)

      shipyard = Fleets.shipyard_panel_for_user_planet(planet.id, current_user.id)
      defense_panel = Defenses.defense_panel_for_user_planet(planet.id, current_user.id)

      base =
        socket
        |> assign(:defense_order, %{})
        |> assign(:planet, new_planet)
        |> assign(:buildings, buildings)
        |> assign(:rates, rates)
        |> assign(:display, display)
        |> assign(:now, now)
        |> assign(:spaceport_fleets, shipyard.fleets)
        |> assign(:shipyard_queue_items, shipyard.queue_items)
        |> assign(:ship_catalog, shipyard.ship_catalog)
        |> assign(:planet_defenses, defense_panel.defenses)
        |> assign(:defense_queue_items, defense_panel.queue_items)
        |> assign(:defense_catalog, defense_panel.defense_catalog)

      if err_list == [] do
        {:noreply,
         assign(base,
           defense_notice: gettext("Defenses queued successfully!"),
           defense_error: nil
         )}
      else
        failed_reasons =
          err_list
          |> Enum.reverse()
          |> Enum.map(&defense_error_reason_label/1)
          |> Enum.join(", ")

        msg =
          "#{ok_count} #{gettext("batch(es) queued")}. #{length(err_list)} #{gettext("failed")}: #{failed_reasons}"

        {:noreply, assign(base, defense_error: msg, defense_notice: nil)}
      end
    end
  end

  def handle_event("grant_test_resources", _params, socket) do
    planet_id = socket.assigns.planet.id
    current_user_id = socket.assigns.current_user.id

    case Planets.grant_test_resources_for_user(planet_id, current_user_id) do
      {:ok, _} ->
        {planet, buildings, rates, display, now} = load_planet_state(planet_id, current_user_id)
        defense_panel = Defenses.defense_panel_for_user_planet(planet_id, current_user_id)

        {:noreply,
         socket
         |> assign(:planet, planet)
         |> assign(:buildings, buildings)
         |> assign(:rates, rates)
         |> assign(:display, display)
         |> assign(:now, now)
         |> assign(:planet_defenses, defense_panel.defenses)
         |> assign(:defense_queue_items, defense_panel.queue_items)
         |> assign(:defense_catalog, defense_panel.defense_catalog)
         |> assign(:shipyard_notice, gettext("Test resources added to this planet."))
         |> assign(:defense_notice, gettext("Test resources added to this planet."))
         |> assign(:defense_error, nil)
         |> assign(:shipyard_error, nil)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Planet not found."))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:shipyard_notice, nil)
         |> assign(:shipyard_error, gettext("Could not add test resources."))}
    end
  end

  # ---------------------------------------------------------------------------
  # Timer
  # ---------------------------------------------------------------------------

  def handle_info(:ui_tick, socket) do
    schedule_ui_tick()
    current_user_id = socket.assigns.current_user.id
    planet_id = socket.assigns.planet.id

    {planet, updated_buildings, new_rates, display, now} =
      load_planet_state(planet_id, current_user_id)

    shipyard = Fleets.shipyard_panel_for_user_planet(planet_id, current_user_id)
    defense_panel = Defenses.defense_panel_for_user_planet(planet_id, current_user_id)

    {:noreply,
     socket
     |> assign(:now, now)
     |> assign(:planet, planet)
     |> assign(:buildings, updated_buildings)
     |> assign(:rates, new_rates)
     |> assign(:display, display)
     |> assign(:spaceport_fleets, shipyard.fleets)
     |> assign(:shipyard_queue_items, shipyard.queue_items)
     |> assign(:ship_catalog, shipyard.ship_catalog)
     |> assign(:planet_defenses, defense_panel.defenses)
     |> assign(:defense_queue_items, defense_panel.queue_items)
     |> assign(:defense_catalog, defense_panel.defense_catalog)}
  end

  defp shipyard_error_reason_label(reason) do
    case reason do
      :spaceport_required ->
        gettext("Spaceport level 1 is required to build ships.")

      :insufficient_resources ->
        gettext("Insufficient resources to queue ships.")

      :fleet_not_found ->
        gettext("Fleet not found.")

      :fleet_unavailable ->
        gettext("Selected fleet is not available from this planet.")

      :queue_scheduling_failed ->
        gettext("Could not schedule ship construction. Please try again.")

      :invalid_queue_request ->
        gettext("Invalid shipyard request.")

      other ->
        to_string(other)
    end
  end

  defp defense_error_reason_label(reason) do
    case reason do
      :defense_center_required ->
        gettext("Defense Center level 1 is required to build defenses.")

      :insufficient_resources ->
        gettext("Insufficient resources to queue defenses.")

      :defense_limit_reached ->
        gettext("Defense limit reached for this planet.")

      :queue_scheduling_failed ->
        gettext("Could not schedule defense construction. Please try again.")

      :invalid_queue_request ->
        gettext("Invalid defense request.")

      other ->
        to_string(other)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp schedule_ui_tick, do: Process.send_after(self(), :ui_tick, @ui_tick_ms)

  defp load_planet_state(planet_id, current_user_id) do
    {:ok, _} = Planets.ensure_building_slots(planet_id)
    :ok = Planets.reconcile_due_constructions(planet_id)

    planet = Planets.get_user_planet!(planet_id, current_user_id)
    {:ok, planet} = Planets.apply_production_tick(planet)
    buildings = Planets.list_buildings(planet_id)
    rates = ProductionEngine.calculate_rates(buildings)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {planet, buildings, rates, resource_display(planet), now}
  end

  defp safe_load_planet_state(planet_id, current_user_id) do
    try do
      {:ok, load_planet_state(planet_id, current_user_id)}
    rescue
      Ecto.NoResultsError ->
        {:error, :not_found}
    end
  end

  defp resource_display(planet) do
    %{
      raw_materials: planet.raw_materials * 1.0,
      microchips: planet.microchips * 1.0,
      hydrogen: planet.hydrogen * 1.0,
      food: planet.food * 1.0,
      credits: planet.credits * 1.0,
      population: planet.population * 1.0
    }
  end

  defp format_rate(rate) when is_float(rate) or is_integer(rate) do
    r = rate * 1.0
    if r >= 0, do: "+#{Float.round(r, 1)}", else: "#{Float.round(r, 1)}"
  end

  defp format_resource(v) when v >= 1_000_000, do: "#{Float.round(v / 1_000_000.0, 1)}M"
  defp format_resource(v) when v >= 10_000, do: "#{round(v / 1_000)}k"
  defp format_resource(v) when v >= 100, do: "#{round(v * 1.0)}"
  defp format_resource(v), do: "#{Float.round(v * 1.0, 1)}"

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

  defp ship_name(type) do
    case Fleets.ship_definition(type) do
      %{name: name} -> name
      _ -> type |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp defense_name(type) do
    case Defenses.defense_definition(type) do
      %{name: name} -> translate_dynamic(name)
      _ -> type |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp defense_quantity(defenses, defense_type) do
    defenses
    |> List.wrap()
    |> Enum.find_value(0, fn defense ->
      if defense.defense_type == defense_type, do: defense.quantity
    end)
  end

  defp queued_defense_quantity(queue_items, defense_type) do
    queue_items
    |> List.wrap()
    |> Enum.reduce(0, fn item, acc ->
      if item.defense_type == defense_type, do: acc + item.quantity, else: acc
    end)
  end

  defp defense_remaining_limit(defense, owned_qty, queued_qty, staged_qty) do
    case Map.get(defense, :max_per_planet) do
      max when is_integer(max) -> max(max - owned_qty - queued_qty - staged_qty, 0)
      _ -> :unlimited
    end
  end

  defp validate_defense_staging(assigns, defense_type, requested_qty) do
    defense = Enum.find(assigns.defense_catalog, &(&1.type == defense_type))

    cond do
      is_nil(defense) ->
        {:error, gettext("Invalid defense request.")}

      requested_qty <= 0 ->
        {:error, gettext("Invalid defense request.")}

      true ->
        owned_qty = defense_quantity(assigns.planet_defenses, defense_type)
        queued_qty = queued_defense_quantity(assigns.defense_queue_items, defense_type)
        staged_qty = Map.get(assigns.defense_order, defense_type, 0)
        remaining = defense_remaining_limit(defense, owned_qty, queued_qty, staged_qty)

        cond do
          remaining == :unlimited ->
            :ok

          remaining <= 0 ->
            {:error,
             gettext(
               "Defense limit reached: existing and queued defenses already use all available slots."
             )}

          requested_qty > remaining ->
            {:error,
             Gettext.gettext(
               NexusDownfallWeb.Gettext,
               "Only %{count} more can be staged for this defense.",
               count: remaining
             )}

          true ->
            :ok
        end
    end
  end

  defp selected_unit_detail(nil), do: nil

  defp selected_unit_detail(%{kind: "ship", type: type}) do
    case Fleets.ship_definition(type) do
      nil ->
        nil

      ship ->
        %{
          kind: :ship,
          name: ship.name,
          description: ship.description,
          image_path: ship_image_path(ship),
          stats: [
            {gettext("Tier"), ship.tier},
            {gettext("Hull"), ship.hull},
            {gettext("Shield"), ship.shield},
            {gettext("Attack"), ship.attack},
            {gettext("Accuracy"), ship.accuracy},
            {gettext("Agility"), ship.agility},
            {gettext("Speed"), ship.speed},
            {gettext("Fuel/s"), ship.fuel_per_s},
            {gettext("Cargo"), ship.cargo},
            {gettext("Build time"), format_duration(ship.build_time_seconds)},
            {gettext("Raw Materials"), format_resource(ship.cost.raw_materials * 1.0)},
            {gettext("Chips"), format_resource(ship.cost.microchips * 1.0)},
            {gettext("Hydrogen"), format_resource(ship.cost.hydrogen * 1.0)}
          ]
        }
    end
  end

  defp selected_unit_detail(%{kind: "defense", type: type}) do
    case Defenses.defense_definition(type) do
      nil ->
        nil

      defense ->
        stats = [
          {gettext("Tier"), defense.tier},
          {gettext("Role"), defense_role_label(defense.role)},
          {gettext("Hull"), defense.hull},
          {gettext("Shield"), defense.shield},
          {gettext("Attack"), defense.attack},
          {gettext("Accuracy"), defense.accuracy},
          {gettext("Energy"), defense.energy},
          {gettext("Build time"), format_duration(defense.build_time_seconds)},
          {gettext("Raw Materials"), format_resource(defense.cost.raw_materials * 1.0)},
          {gettext("Chips"), format_resource(defense.cost.microchips * 1.0)},
          {gettext("Hydrogen"), format_resource(defense.cost.hydrogen * 1.0)},
          {gettext("Target priority"), target_priority_label(defense.target_priority)},
          {gettext("Rules"), defense_rules_label(defense.rules)}
        ]

        stats =
          case Map.get(defense, :max_per_planet) do
            max when is_integer(max) -> stats ++ [{gettext("Limit"), max}]
            _ -> stats
          end

        %{
          kind: :defense,
          name: defense.name,
          description: defense.description,
          image_path: defense_image_path(defense),
          stats: stats
        }
    end
  end

  defp selected_unit_detail(_), do: nil

  defp ship_image_path(%{tier: tier}) when tier >= 3, do: "/images/ships/ship-b.svg"
  defp ship_image_path(_ship), do: "/images/ships/ship-a.svg"

  defp defense_image_path(_defense), do: "/images/planet-images/defense-center.png"

  defp target_priority_label([]), do: gettext("No target priority")

  defp target_priority_label(targets) do
    targets
    |> Enum.map(&target_category_label/1)
    |> Enum.join(" > ")
  end

  defp defense_rules_label([]), do: gettext("No special rules")

  defp defense_rules_label(rules) do
    rules
    |> Enum.map(&defense_rule_label/1)
    |> Enum.join(", ")
  end

  defp target_category_label("Light"), do: gettext("Light")
  defp target_category_label("Medium"), do: gettext("Medium")
  defp target_category_label("Heavy"), do: gettext("Heavy")
  defp target_category_label("Capital"), do: gettext("Capital")
  defp target_category_label("Civil"), do: gettext("Civil")
  defp target_category_label("Siege"), do: gettext("Siege")
  defp target_category_label("Support"), do: gettext("Support")
  defp target_category_label("Conquest"), do: gettext("Conquest")
  defp target_category_label(other), do: other

  defp defense_rule_label("Fixed Defense"), do: gettext("Fixed Defense")
  defp defense_rule_label("Saturation Fire"), do: gettext("Saturation Fire")
  defp defense_rule_label("Anti-squadron Accuracy"), do: gettext("Anti-squadron Accuracy")
  defp defense_rule_label("Piercing Shot"), do: gettext("Piercing Shot")
  defp defense_rule_label("Ion Pulse"), do: gettext("Ion Pulse")
  defp defense_rule_label("Shield Overload"), do: gettext("Shield Overload")
  defp defense_rule_label("Critical Infrastructure"), do: gettext("Critical Infrastructure")
  defp defense_rule_label("Anti-siege"), do: gettext("Anti-siege")
  defp defense_rule_label("Orbital Interception"), do: gettext("Orbital Interception")
  defp defense_rule_label("Anti-blockade"), do: gettext("Anti-blockade")
  defp defense_rule_label("Conquest Resistance"), do: gettext("Conquest Resistance")
  defp defense_rule_label(other), do: other

  defp defense_role_label("Cheap anti-light defense"), do: gettext("Cheap anti-light defense")
  defp defense_role_label("Precise anti-light defense"), do: gettext("Precise anti-light defense")
  defp defense_role_label("Anti-medium defense"), do: gettext("Anti-medium defense")
  defp defense_role_label("Heavy armor piercing"), do: gettext("Heavy armor piercing")
  defp defense_role_label("Shield suppression"), do: gettext("Shield suppression")
  defp defense_role_label("Anti-capital defense"), do: gettext("Anti-capital defense")
  defp defense_role_label("Global protection"), do: gettext("Global protection")
  defp defense_role_label("Bombardment counter"), do: gettext("Bombardment counter")
  defp defense_role_label("Blockade counter"), do: gettext("Blockade counter")

  defp defense_role_label("Anti-conquest infrastructure"),
    do: gettext("Anti-conquest infrastructure")

  defp defense_role_label(other), do: other

  defp translate_dynamic(msgid), do: Gettext.gettext(NexusDownfallWeb.Gettext, msgid)

  # Return a level-0 placeholder image for buildings not yet built
  defp building_img_level0("farm"), do: "unconstructed2.png"
  defp building_img_level0("residential"), do: "unconstructed3.png"
  defp building_img_level0(_), do: "unconstructed.png"

  defp building_description("hydrogen_extractor"),
    do:
      gettext(
        "Extracts hydrogen from atmospheric layers using advanced molecular separators. Hydrogen is vital for propelling fleets and powering fusion reactors."
      )

  defp building_description("microchip_factory"),
    do:
      gettext(
        "Manufactures high-precision quantum microchips for ship construction and advanced technologies. Higher level means better performance and lower defect rate."
      )

  defp building_description("spaceport"),
    do:
      gettext(
        "Fleet operations center. Manages launches, landings and maintenance. Enables trade routes, exploration missions and combat operations."
      )

  defp building_description("residential"),
    do:
      gettext(
        "Residential zone housing the planet's population. Higher levels increase capacity and quality of life, attracting new colonists to the system."
      )

  defp building_description("command_center"),
    do:
      gettext(
        "The planet's nerve center. Coordinates all administrative, military and civilian operations. Its level determines the expansion limits of other structures."
      )

  defp building_description("mine_raw"),
    do:
      gettext(
        "Extracts raw materials from the planetary subsoil with high-energy plasma drills. A fundamental resource for all construction and research."
      )

  defp building_description("farm"),
    do:
      gettext(
        "Hydroponic crops and bioreactors that produce food for the population. Without sufficient supply, overall productive efficiency decreases."
      )

  defp building_description("laboratory"),
    do:
      gettext(
        "Scientific and technological research center. Accelerates the development of new technologies and unlocks synergistic improvements for other structures."
      )

  defp building_description("power_plant"),
    do:
      gettext(
        "Generates the energy needed to keep all planetary structures operational. A negative energy balance reduces overall productive efficiency."
      )

  defp building_description("nuclear_reactor"),
    do:
      gettext(
        "High-efficiency nuclear fission reactor. Produces more energy per level than the conventional generator, ideal for planets with high industrial demand."
      )

  defp building_description("defense_center"),
    do:
      gettext(
        "Planetary defense coordination center. Manages turrets, shields and early warning systems to protect the planet from external attacks."
      )

  defp building_description("component_factory"),
    do:
      gettext(
        "Factory specialized in advanced electronic components. Complements microchip production with a higher-precision manufacturing chain."
      )

  defp building_description(_), do: gettext("Planetary structure.")

  defp production_stats("hydrogen_extractor", rates),
    do: {"\u{1F4A7}", gettext("Hydrogen Production"), rates.hydrogen * 1.0}

  defp production_stats("microchip_factory", rates),
    do: {"\u{1F4BE}", gettext("Microchip Production"), rates.microchips * 1.0}

  defp production_stats("mine_raw", rates),
    do: {"\u26CF\uFE0F", gettext("Raw Materials Production"), rates.raw_materials * 1.0}

  defp production_stats("farm", rates),
    do: {"\u{1F33E}", gettext("Food Production"), rates.food * 1.0}

  defp production_stats("component_factory", rates),
    do: {"\u{1F4BE}", gettext("Microchip Production"), rates.microchips * 1.0}

  defp production_stats(_, _rates), do: {"\u{1F4E6}", gettext("Production"), 0.0}

  defp building_name("hydrogen_extractor"), do: gettext("Hydrogen Mine")
  defp building_name("microchip_factory"), do: gettext("Chip Factory")
  defp building_name("spaceport"), do: gettext("Spaceport")
  defp building_name("residential"), do: gettext("Residential Area")
  defp building_name("command_center"), do: gettext("Command Center")
  defp building_name("mine_raw"), do: gettext("Raw Material Mine")
  defp building_name("farm"), do: gettext("Farm")
  defp building_name("laboratory"), do: gettext("Research Center")
  defp building_name("power_plant"), do: gettext("Energy Generator")
  defp building_name("nuclear_reactor"), do: gettext("Nuclear Reactor")
  defp building_name("defense_center"), do: gettext("Defense Center")
  defp building_name("component_factory"), do: gettext("Component Factory")
  defp building_name(type), do: type
end
