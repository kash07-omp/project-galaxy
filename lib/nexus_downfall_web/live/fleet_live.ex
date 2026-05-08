defmodule NexusDownfallWeb.FleetLive do
  @moduledoc "Fleet command screen - create fleets and inspect their composition."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Fleets
  alias Phoenix.LiveView.JS
  alias NexusDownfall.Cards

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        NexusDownfall.PubSub,
        Fleets.fleet_updates_topic_for_user(socket.assigns.current_user.id)
      )

      Process.send_after(self(), :mission_tick, 1_000)
    end

    {:ok,
     socket
     |> assign(:now, DateTime.utc_now() |> DateTime.truncate(:second))
     |> assign_fleet_page()}
  end

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col overflow-hidden bg-[#050912] font-sans select-none">
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        active_tab="fleet"
      />
      <main class="flex-1 overflow-y-auto bg-[radial-gradient(circle_at_16%_12%,#12385f_0%,#071426_28%,#050912_55%,#03060d_100%)] p-3 md:p-5">
        <div class="mx-auto max-w-[1500px]">
          <section class="relative mb-4 overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#071325]/70 shadow-[0_18px_60px_rgba(8,145,178,0.2)]">
            <div class="absolute inset-0 bg-[linear-gradient(115deg,rgba(56,189,248,0.12),transparent_35%,rgba(34,197,94,0.08)_62%,transparent_78%)]" />
            <div class="relative flex flex-wrap items-end justify-between gap-4 px-4 py-4 md:px-5">
              <div>
                <p class="text-[10px] uppercase tracking-[0.22em] text-cyan-300/80">
                  {gettext("Fleet Operations")}
                </p>
                
                <h1 class="mt-1 text-xl font-bold text-white md:text-2xl">
                  {gettext("Fleet Management")}
                </h1>
                
                <p class="mt-1 text-xs text-cyan-100/80 md:text-sm">
                  {gettext(
                    "Monitor each fleet, inspect every ship class and prepare mission dispatches."
                  )}
                </p>
              </div>
              
              <div class="grid grid-cols-2 gap-2 text-right md:grid-cols-4">
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500">{gettext("Fleets")}</p>
                  
                  <p class="text-lg font-bold text-cyan-200">{@fleet_metrics.total_fleets}</p>
                </div>
                
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500">{gettext("Ships")}</p>
                  
                  <p class="text-lg font-bold text-cyan-200">{@fleet_metrics.total_ships}</p>
                </div>
                
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500">{gettext("Worlds")}</p>
                  
                  <p class="text-lg font-bold text-cyan-200">{@fleet_metrics.home_worlds}</p>
                </div>
                
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500">{gettext("Ready")}</p>
                  
                  <p class="text-lg font-bold text-emerald-300">{@fleet_metrics.ready_fleets}</p>
                </div>
              </div>
            </div>
          </section>
          
          <div class="grid gap-4 xl:grid-cols-[280px_minmax(0,1fr)]">
            <aside class="space-y-4 xl:sticky xl:top-4 xl:self-start">
              <section class="overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#0a1528]/95 shadow-[0_18px_44px_rgba(2,8,22,0.62)]">
                <div class="border-b border-cyan-500/15 bg-[linear-gradient(170deg,rgba(8,145,178,0.22),rgba(8,145,178,0.03))] px-4 py-3">
                  <h2 class="text-lg font-bold text-white">{gettext("Fleet Management")}</h2>
                  
                  <p class="mt-1 text-xs text-cyan-100/80">
                    {gettext("Create and organize your operational fleets.")}
                  </p>
                </div>
                
                <div class="p-4">
                  <button
                    phx-click="open_create_fleet_modal"
                    class="w-full rounded-xl bg-[linear-gradient(90deg,#0ea5e9,#22d3ee)] px-4 py-2.5 text-sm font-semibold text-white shadow-[0_8px_24px_rgba(14,165,233,0.45)] transition hover:brightness-110"
                  >
                    + {gettext("New Fleet")}
                  </button>
                  <div class="mt-3 grid grid-cols-2 gap-2">
                    <div class="rounded-lg border border-cyan-500/20 bg-[#060d18]/70 px-3 py-2">
                      <p class="text-[10px] uppercase tracking-wide text-gray-500">
                        {gettext("Fleets")}
                      </p>
                      
                      <p class="text-base font-bold text-cyan-200">{@fleet_metrics.total_fleets}</p>
                    </div>
                    
                    <div class="rounded-lg border border-cyan-500/20 bg-[#060d18]/70 px-3 py-2">
                      <p class="text-[10px] uppercase tracking-wide text-gray-500">
                        {gettext("Ships")}
                      </p>
                      
                      <p class="text-base font-bold text-cyan-200">{@fleet_metrics.total_ships}</p>
                    </div>
                  </div>
                  
                  <div class="mt-4 rounded-xl border border-cyan-500/20 bg-[#050f1d]/80 p-3">
                    <div class="mb-2 flex items-center justify-between gap-2">
                      <h3 class="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">
                        {gettext("Fleet Filters")}
                      </h3>
                      
                      <span class="rounded-full border border-amber-600/60 bg-amber-900/30 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-300">
                        {gettext("PRO")}
                      </span>
                    </div>
                    
                    <div class={[
                      "space-y-2 transition",
                      if(!@premium_access,
                        do: "pointer-events-none opacity-45 grayscale-[0.35]",
                        else: "opacity-100"
                      )
                    ]}>
                      <div>
                        <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500">
                          {gettext("Mission")}
                        </label>
                        <select class="w-full rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-xs text-gray-300">
                          <option>{gettext("All missions")}</option>
                        </select>
                      </div>
                      
                      <div>
                        <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500">
                          {gettext("Planet")}
                        </label>
                        <select class="w-full rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-xs text-gray-300">
                          <option>{gettext("All planets")}</option>
                        </select>
                      </div>
                      
                      <div>
                        <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500">
                          {gettext("Search")}
                        </label>
                        <input
                          type="text"
                          class="w-full rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-xs text-gray-300"
                          placeholder={gettext("Fleet name...")}
                        />
                      </div>
                    </div>
                    
                    <button
                      :if={!@premium_access}
                      type="button"
                      class="mt-3 w-full rounded-lg border border-amber-500/70 bg-amber-900/35 px-3 py-2 text-xs font-semibold uppercase tracking-wide text-amber-200 transition hover:bg-amber-900/55"
                    >
                      {gettext("Unlock with PRO")}
                    </button>
                  </div>
                  
                  <p class="mt-3 text-[11px] text-gray-500">
                    {gettext("Advanced filters are visible but restricted to PRO commanders.")}
                  </p>
                </div>
              </section>
            </aside>
            
            <section class="rounded-2xl border border-cyan-500/20 bg-[#081225]/90 p-3 shadow-[0_18px_44px_rgba(2,8,22,0.62)] md:p-4">
              <div class="mb-3 hidden items-center gap-2 rounded-xl border border-cyan-500/15 bg-[#050e1c]/90 px-3 py-2 text-[10px] font-semibold uppercase tracking-wider text-cyan-300/70 xl:flex">
                <div class="w-[72px] shrink-0">{gettext("Admiral")}</div>
                
                <div class="flex-1 grid grid-cols-[minmax(0,1fr)_200px_180px_auto] gap-2 items-center">
                  <span>{gettext("Fleet")}</span> <span>{gettext("Location")}</span>
                  <span>{gettext("Mission")}</span>
                  <span class="text-right">{gettext("Actions")}</span>
                </div>
              </div>
              
              <%= if @fleets == [] do %>
                <div class="rounded-2xl border border-dashed border-cyan-600/30 bg-[#060d18]/80 px-6 py-12 text-center">
                  <p class="text-lg font-semibold text-white">
                    {gettext("No fleets registered yet.")}
                  </p>
                  
                  <p class="mx-auto mt-2 max-w-xl text-sm text-gray-400">
                    {gettext("Create a fleet to start assigning ships from the spaceport queue.")}
                  </p>
                  
                  <button
                    phx-click="open_create_fleet_modal"
                    class="mt-5 rounded-xl bg-cyan-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-cyan-500"
                  >
                    {gettext("Create new fleet")}
                  </button>
                </div>
              <% else %>
                <div class="space-y-2">
                  <%= for fleet <- @fleets do %>
                    <article class="rounded-xl border border-cyan-500/20 bg-[linear-gradient(145deg,#081423,#050d18)] p-3 shadow-[0_10px_28px_rgba(8,145,178,0.1)] transition hover:border-cyan-400/45">
                      <div class="relative flex gap-3">
                        <%!-- Admiral card - spans both rows height --%>
                        <div class="relative w-[110px] shrink-0 self-stretch overflow-hidden rounded-xl border border-cyan-500/20 bg-[#030a15]">
                          <%= if fleet.admiral_card do %>
                            <%!-- Assigned admiral card - show full art --%>
                            <img
                              src={"/images/#{fleet.admiral_card.image_path}"}
                              alt={fleet.admiral_card.name}
                              class="absolute inset-0 h-full w-full object-cover object-top"
                              draggable="false"
                            />
                            <div class="absolute inset-0 bg-gradient-to-t from-black/85 via-transparent to-transparent" />
                            <div class="absolute bottom-0 left-0 right-0 p-2">
                              <p class="text-center text-[9px] font-bold leading-tight text-white drop-shadow">
                                {fleet.admiral_card.name}
                              </p>
                              
                              <button
                                type="button"
                                phx-click="open_assign_admiral"
                                phx-value-fleet_id={fleet.id}
                                class="mt-1 w-full rounded border border-cyan-500/50 bg-cyan-900/50 px-1 py-0.5 text-[8px] font-semibold uppercase tracking-wide text-cyan-200 transition hover:bg-cyan-800/60"
                              >
                                {gettext("Change")}
                              </button>
                            </div>
                          <% else %>
                            <%!-- No admiral - show placeholder and assign button --%>
                            <div class="absolute inset-0 flex flex-col items-center justify-center gap-2 p-2">
                              <div class="flex h-10 w-10 items-center justify-center rounded-full border border-gray-700/50 bg-gray-900/50">
                                <span class="text-2xl opacity-20">★</span>
                              </div>
                              
                              <p class="text-center text-[8px] text-gray-600">
                                {gettext("No admiral")}
                              </p>
                              
                              <button
                                type="button"
                                phx-click="open_assign_admiral"
                                phx-value-fleet_id={fleet.id}
                                class="w-full rounded border border-cyan-600/50 bg-cyan-900/30 px-1 py-1 text-[8px] font-semibold uppercase tracking-wide text-cyan-300 transition hover:bg-cyan-800/40"
                              >
                                {gettext("Assign")}
                              </button>
                            </div>
                          <% end %>
                        </div>
                         <%!-- Right side: row 1 (info) + row 2 (ships) --%>
                        <div class="flex min-w-0 flex-1 flex-col gap-2">
                          <%!-- Row 1: fleet name | planet | mission/power | send mission --%>
                          <div class="flex flex-wrap items-stretch gap-2 xl:grid xl:grid-cols-[minmax(0,1fr)_200px_180px_auto] xl:items-center">
                            <div class="rounded-lg border border-cyan-500/15 bg-[#050f1d]/70 px-3 py-2">
                              <div class="flex items-center gap-2">
                                <h3 class="truncate text-sm font-bold text-white">{fleet.name}</h3>
                                
                                <span class={fleet_status_badge_class(fleet.status)}>
                                  {fleet_status_label(fleet.status)}
                                </span>
                              </div>
                            </div>
                            
                            <div class="rounded-lg border border-cyan-500/15 bg-[#050f1d]/70 px-3 py-2">
                              <p class="text-[10px] uppercase tracking-wide text-gray-500">
                                {gettext("Planet")}
                              </p>
                              
                              <p class="truncate text-sm font-semibold text-white">
                                {fleet.home_planet.name}
                              </p>
                              
                              <p class="text-[11px] text-gray-400">
                                {gettext("System")} {fleet.home_planet.solar_system.number}
                              </p>
                            </div>
                            
                            <div class="rounded-lg border border-cyan-500/15 bg-[#050f1d]/70 px-3 py-2">
                              <p class="text-[10px] uppercase tracking-wide text-gray-500">
                                {gettext("Current mission")}
                              </p>
                              
                              <p class="text-sm font-semibold text-cyan-200">
                                {fleet_status_label(fleet.status)}
                              </p>
                              
                              <p class="text-[11px] text-gray-400">
                                {gettext("Power")}: {fleet_power(fleet, @ship_catalog)}
                              </p>
                            </div>
                            
                            <div class="flex items-center justify-end">
                              <button
                                type="button"
                                phx-click="open_send_mission_modal"
                                phx-value-fleet_id={fleet.id}
                                disabled={fleet.status != "idle"}
                                class={[
                                  "rounded-lg border px-3 py-2 text-xs font-semibold uppercase tracking-wide transition",
                                  if(fleet.status == "idle",
                                    do:
                                      "border-emerald-500/60 bg-emerald-900/35 text-emerald-200 hover:bg-emerald-800/45",
                                    else:
                                      "cursor-not-allowed border-gray-700 bg-gray-900/70 text-gray-500"
                                  )
                                ]}
                              >
                                {gettext("Send mission")}
                              </button>
                            </div>
                          </div>
                          
                          <%= if mission = @active_missions_by_fleet[fleet.id] do %>
                            <div class="rounded-lg border border-cyan-500/20 bg-[#031122]/80 px-3 py-2">
                              <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
                                <p class="text-[10px] font-semibold uppercase tracking-wide text-cyan-300">
                                  {mission_progress_title(mission, @now)}
                                </p>
                                
                                <p class="text-[11px] text-gray-300">
                                  {mission_progress_label(mission, @now)}
                                </p>
                              </div>
                              
                              <div class="h-2 w-full overflow-hidden rounded-full bg-cyan-950/70">
                                <div
                                  class="h-full rounded-full bg-gradient-to-r from-cyan-500 to-emerald-400 transition-all duration-500"
                                  style={"width: #{mission_progress_percent(mission, @now)}%"}
                                />
                              </div>
                              
                              <div class="mt-2 grid gap-1 text-[11px] text-gray-400 md:grid-cols-3">
                                <p>
                                  <span class="text-gray-500">{gettext("Origin")}:</span>
                                  <span class="text-gray-200">{mission_origin_name(mission)}</span>
                                </p>
                                
                                <p>
                                  <span class="text-gray-500">{gettext("Destination")}:</span>
                                  <span class="text-gray-200">
                                    {mission_destination_name(mission)}
                                  </span>
                                </p>
                                
                                <p>
                                  <span class="text-gray-500">
                                    {mission_eta_label(mission, @now)}:
                                  </span>
                                  <span class="text-gray-200">
                                    {mission_remaining_label(mission, @now)}
                                  </span>
                                </p>
                              </div>
                            </div>
                          <% end %>
                           <%!-- Row 2: ship manifest - full width below fleet info --%>
                          <div class="rounded-lg border border-cyan-500/10 bg-[#030a15]/60 p-2">
                            <p class="mb-1.5 text-[9px] uppercase tracking-widest text-gray-600">
                              {gettext("Ship Manifest")}
                            </p>
                            
                            <div class="flex flex-wrap gap-1.5">
                              <%= for ship <- @ship_catalog do %>
                                <div class="flex min-w-[90px] items-center gap-1.5 rounded-lg border border-cyan-500/15 bg-[#030914]/85 px-2 py-1">
                                  <img
                                    src={"/images/ships/#{ship.type}.svg"}
                                    onerror="this.style.display='none'"
                                    alt={translate_dynamic(ship.name)}
                                    class="h-6 w-6 rounded bg-black/30 p-0.5 object-contain"
                                    draggable="false"
                                  />
                                  <div class="min-w-0">
                                    <p class="truncate text-[9px] text-gray-400">
                                      {translate_dynamic(ship.name)}
                                    </p>
                                    
                                    <p class="text-xs font-bold leading-none text-white">
                                      {Fleets.ship_quantity(fleet, ship.type)}
                                    </p>
                                  </div>
                                </div>
                              <% end %>
                            </div>
                          </div>
                        </div>
                        
                        <%!-- Inline admiral picker - shown when assign_admiral_fleet_id == fleet.id --%>
                        <%= if @assign_admiral_fleet_id == fleet.id do %>
                          <div class="absolute inset-0 z-10 flex flex-col overflow-hidden rounded-xl bg-[#07111f]/95 backdrop-blur-sm">
                            <div class="flex items-center justify-between border-b border-cyan-500/15 px-4 py-2.5">
                              <p class="text-xs font-semibold uppercase tracking-wider text-cyan-300">
                                {gettext("Choose an admiral from your deck")}
                              </p>
                              
                              <button
                                type="button"
                                phx-click="cancel_assign_admiral"
                                class="rounded p-0.5 text-gray-500 transition hover:text-gray-300"
                              >
                                ✕
                              </button>
                            </div>
                            
                            <div class="flex flex-1 flex-wrap items-start gap-3 overflow-y-auto p-3">
                              <% assigned_card_ids =
                                assigned_card_ids_for_other_fleets(@fleets, fleet.id) %>
                              <button
                                type="button"
                                phx-click="unassign_admiral_card"
                                phx-value-fleet_id={fleet.id}
                                class="group flex w-[110px] flex-col overflow-hidden rounded-xl border border-amber-400/50 bg-[#0f1218] transition hover:border-amber-300 hover:shadow-[0_0_16px_rgba(250,204,21,0.2)]"
                              >
                                <div class="flex h-28 w-full items-center justify-center bg-[#090c12]">
                                  <span class="text-5xl font-black leading-none text-amber-300">
                                    ✕
                                  </span>
                                </div>
                                
                                <div class="p-2">
                                  <p class="text-center text-[10px] font-bold text-amber-100">
                                    {gettext("Unassign admiral")}
                                  </p>
                                </div>
                              </button>
                              <%= if @user_admiral_cards == [] do %>
                                <p class="text-sm text-gray-500">
                                  {gettext("No admiral cards in your deck.")}
                                </p>
                              <% else %>
                                <%= for uc <- @user_admiral_cards do %>
                                  <% assigned_elsewhere =
                                    MapSet.member?(assigned_card_ids, uc.card_id) %>
                                  <button
                                    type="button"
                                    disabled={assigned_elsewhere}
                                    title={
                                      if assigned_elsewhere,
                                        do: gettext("Already assigned to another fleet."),
                                        else: nil
                                    }
                                    phx-click={
                                      if assigned_elsewhere, do: nil, else: "assign_admiral_card"
                                    }
                                    phx-value-fleet_id={fleet.id}
                                    phx-value-card_id={uc.card_id}
                                    class={[
                                      "group flex w-[110px] flex-col overflow-hidden rounded-xl border bg-[#050f1d] transition",
                                      if(assigned_elsewhere,
                                        do:
                                          "cursor-not-allowed border-gray-600/40 opacity-45 grayscale",
                                        else:
                                          "border-cyan-500/20 hover:border-cyan-400/60 hover:shadow-[0_0_16px_rgba(34,211,238,0.2)]"
                                      )
                                    ]}
                                  >
                                    <div class="relative h-28 w-full overflow-hidden">
                                      <img
                                        src={"/images/#{uc.card.image_path}"}
                                        alt={uc.card.name}
                                        class={[
                                          "h-full w-full object-cover object-top transition",
                                          if(assigned_elsewhere,
                                            do: "",
                                            else: "group-hover:scale-105"
                                          )
                                        ]}
                                        draggable="false"
                                      />
                                    </div>
                                    
                                    <div class="p-2">
                                      <p class="text-center text-[10px] font-bold text-white">
                                        {uc.card.name}
                                      </p>
                                      
                                      <p class="text-center text-[8px] capitalize text-cyan-300/70">
                                        {uc.card.rarity}
                                      </p>
                                    </div>
                                  </button>
                                <% end %>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </article>
                  <% end %>
                </div>
              <% end %>
            </section>
          </div>
        </div>
      </main>
      
      <.modal
        :if={@show_create_modal}
        id="create-fleet-modal"
        show
        on_cancel={JS.push("close_create_fleet_modal")}
      >
        <div class="relative overflow-hidden rounded-2xl border border-cyan-500/30 bg-[#0c1422]">
          <div class="relative h-32 overflow-hidden">
            <img
              src="/images/planet-images/barraks.jpg"
              class="absolute inset-0 h-full w-full object-cover"
              draggable="false"
            />
            <div class="absolute inset-0 bg-gradient-to-b from-black/20 via-black/50 to-black/90" />
            <div class="absolute bottom-3 left-4">
              <h2 id="create-fleet-modal-title" class="text-xl font-bold text-white">
                {gettext("Create fleet")}
              </h2>
              
              <p id="create-fleet-modal-description" class="mt-1 text-xs text-gray-300">
                {gettext(
                  "Create a named fleet, assign its home planet and optionally an admiral card."
                )}
              </p>
            </div>
          </div>
          
          <div class="space-y-4 p-5">
            <%= if @fleet_error do %>
              <div class="rounded-xl border border-red-700 bg-red-950/40 px-3 py-2 text-sm text-red-300">
                {@fleet_error}
              </div>
            <% end %>
            
            <form phx-submit="create_fleet" class="space-y-4">
              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {gettext("Fleet name")}
                </label>
                <input
                  type="text"
                  name="name"
                  value={@fleet_form.name}
                  placeholder={gettext("Choose a name for your new fleet")}
                  class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white placeholder:text-gray-600 focus:border-cyan-500 focus:outline-none"
                />
              </div>
              
              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {gettext("Home planet")}
                </label>
                <select
                  name="planet_id"
                  class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none"
                >
                  <option value="">{gettext("Select one of your planets")}</option>
                  
                  <%= for planet <- @planets do %>
                    <option value={planet.id} selected={to_string(planet.id) == @fleet_form.planet_id}>
                      {planet_option_label(planet)}
                    </option>
                  <% end %>
                </select>
              </div>
              
              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {gettext("Assigned admiral")}
                </label>
                <select
                  name="admiral_card_id"
                  class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none"
                >
                  <option value="">{gettext("No admiral")}</option>
                  
                  <%= for uc <- @user_admiral_cards do %>
                    <option
                      value={uc.card_id}
                      selected={to_string(uc.card_id) == @fleet_form.admiral_card_id}
                    >
                      {uc.card.name}
                    </option>
                  <% end %>
                </select>
              </div>
              
              <div class="flex flex-col-reverse gap-3 border-t border-gray-800 pt-4 sm:flex-row sm:justify-end">
                <button
                  type="button"
                  phx-click="close_create_fleet_modal"
                  class="rounded-lg border border-gray-700 bg-gray-950 px-4 py-2.5 text-sm font-medium text-gray-200 transition hover:border-gray-500"
                >
                  {gettext("Cancel")}
                </button>
                <button
                  type="submit"
                  class="rounded-lg bg-cyan-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-cyan-500"
                >
                  {gettext("Create fleet")}
                </button>
              </div>
            </form>
          </div>
        </div>
      </.modal>
      
      <.modal
        :if={@show_send_mission_modal}
        id="send-mission-modal"
        show
        on_cancel={JS.push("close_send_mission_modal")}
      >
        <div class="relative overflow-hidden rounded-2xl border border-emerald-500/30 bg-[#0c1422]">
          <div class="relative h-32 overflow-hidden">
            <img
              src="/images/planet-images/shipyard.jpg"
              class="absolute inset-0 h-full w-full object-cover"
              draggable="false"
            />
            <div class="absolute inset-0 bg-gradient-to-b from-black/20 via-black/50 to-black/90" />
            <div class="absolute bottom-3 left-4">
              <h2 class="text-xl font-bold text-white">{gettext("Send mission")}</h2>
              
              <p class="mt-1 text-xs text-gray-300">
                {gettext("Choose the mission type first, then narrow the target step by step.")}
              </p>
            </div>
          </div>
          
          <div class="space-y-4 p-5">
            <%= if @mission_error do %>
              <div class="rounded-xl border border-red-700 bg-red-950/40 px-3 py-2 text-sm text-red-300">
                {@mission_error}
              </div>
            <% end %>
            
            <form phx-submit="send_mission" phx-change="mission_form_changed" class="space-y-4">
              <input type="hidden" name="fleet_id" value={@mission_form.fleet_id} />
              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                  {gettext("Mission")}
                </label>
                <select
                  name="mission_type"
                  class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none"
                >
                  <%= for option <- mission_options(@selected_mission_fleet) do %>
                    <option
                      value={option.value}
                      selected={option.value == @mission_form.mission_type}
                      disabled={!option.enabled?}
                    >
                      {option.label}
                    </option>
                  <% end %>
                </select>
              </div>
              
              <%= if @mission_form.mission_type in ["colonization", "transport", "attack"] do %>
                <div class="grid gap-4 md:grid-cols-3">
                  <div>
                    <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                      {gettext("Galaxy")}
                    </label>
                    <select
                      name="galaxy_id"
                      class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none"
                    >
                      <option value="">{gettext("Select galaxy")}</option>
                      
                      <%= for galaxy <- @mission_galaxies do %>
                        <option
                          value={galaxy.id}
                          selected={to_string(galaxy.id) == @mission_form.galaxy_id}
                        >
                          {mission_galaxy_label(galaxy)}
                        </option>
                      <% end %>
                    </select>
                  </div>
                  
                  <div>
                    <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                      {gettext("System")}
                    </label>
                    <select
                      name="system_id"
                      disabled={@mission_form.galaxy_id == ""}
                      class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none disabled:cursor-not-allowed disabled:text-gray-500"
                    >
                      <option value="">{gettext("Select system")}</option>
                      
                      <%= for system <- @mission_systems do %>
                        <option
                          value={system.id}
                          selected={to_string(system.id) == @mission_form.system_id}
                        >
                          {mission_system_label(system)}
                        </option>
                      <% end %>
                    </select>
                  </div>
                  
                  <div>
                    <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500">
                      {gettext("Planet")}
                    </label>
                    <select
                      name="target_planet_id"
                      disabled={@mission_form.system_id == ""}
                      class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none disabled:cursor-not-allowed disabled:text-gray-500"
                    >
                      <option value="">{gettext("Select planet")}</option>
                      
                      <%= for target <- @mission_targets do %>
                        <option
                          value={target.id}
                          selected={to_string(target.id) == @mission_form.target_planet_id}
                        >
                          {mission_target_label(target)}
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>
                
                <%= if @mission_form.mission_type == "colonization" do %>
                  <p class="text-xs text-gray-400">
                    {gettext(
                      "If another commander arrives first, your colonizer will automatically return."
                    )}
                  </p>
                <% else %>
                  <%= if @mission_form.mission_type == "transport" do %>
                    <div
                      :if={owned_transport_targets(@planets, @selected_mission_fleet) != []}
                      class="rounded-xl border border-emerald-500/20 bg-emerald-950/15 p-3"
                    >
                      <p class="text-xs font-semibold uppercase tracking-wider text-emerald-300">
                        {gettext("Own planets")}
                      </p>
                      <div class="mt-2 flex flex-wrap gap-2">
                        <%= for planet <- owned_transport_targets(@planets, @selected_mission_fleet) do %>
                          <button
                            type="button"
                            phx-click="select_owned_transport_target"
                            phx-value-galaxy_id={planet.solar_system.galaxy.id}
                            phx-value-system_id={planet.solar_system_id}
                            phx-value-target_planet_id={planet.id}
                            class="rounded-lg border border-emerald-500/30 bg-emerald-950/35 px-3 py-2 text-left text-xs text-emerald-100 transition hover:border-emerald-300/70 hover:bg-emerald-900/40"
                          >
                            <span class="block font-semibold text-white">
                              {mission_planet_name(planet)}
                            </span>
                            <span class="text-emerald-300/80">{planet_coordinates(planet)}</span>
                          </button>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%= if @mission_form.mission_type == "transport" do %>
                    <div class="rounded-xl border border-cyan-500/20 bg-[#050f1d]/80 p-3">
                      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
                        <div>
                          <p class="text-xs font-semibold uppercase tracking-wider text-cyan-300">
                            {gettext("Cargo")}
                          </p>
                          
                          <p class="mt-1 text-[11px] text-gray-400">
                            {gettext("Hydrogen cargo is checked after reserving round-trip fuel.")}
                          </p>
                        </div>
                        
                        <div class="rounded-lg border border-cyan-500/20 bg-[#031122] px-3 py-2 text-right">
                          <p class="text-[10px] uppercase tracking-wide text-gray-500">
                            {gettext("Cargo capacity")}
                          </p>
                          
                          <p class="text-sm font-bold text-cyan-100">
                            {format_number(transport_cargo_total(@mission_form))} / {format_number(
                              transport_cargo_capacity(@selected_mission_fleet)
                            )}
                          </p>
                          
                          <p class="text-[11px] text-gray-400">
                            {gettext("Remaining")}: {format_number(
                              transport_remaining_capacity(@mission_form, @selected_mission_fleet)
                            )}
                          </p>
                        </div>
                      </div>
                      
                      <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
                        <%= for resource <- transport_resource_fields() do %>
                          <div class="min-w-0">
                            <label class="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-gray-500">
                              {transport_resource_label(resource)}
                            </label>
                            <div class="grid min-w-[7.5rem] grid-cols-1 gap-1.5">
                              <input
                                type="number"
                                name={to_string(resource)}
                                min="0"
                                max={
                                  transport_resource_input_max(
                                    @mission_form,
                                    @selected_mission_fleet,
                                    resource
                                  )
                                }
                                step="1"
                                value={Map.get(@mission_form, resource)}
                                class="min-w-0 rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-sm tabular-nums text-white placeholder:text-gray-600 focus:border-cyan-500 focus:outline-none"
                              />
                              <button
                                type="button"
                                phx-click="max_transport_resource"
                                phx-value-resource={resource}
                                class="w-full rounded-lg border border-cyan-500/40 bg-cyan-950/60 px-2 py-2 text-[10px] font-semibold uppercase tracking-wide text-cyan-200 transition hover:border-cyan-300/70 hover:bg-cyan-900/70"
                              >
                                {gettext("Max")}
                              </button>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% else %>
                    <div class="rounded-xl border border-red-500/20 bg-red-950/15 p-3">
                      <p class="text-xs font-semibold uppercase tracking-wider text-red-300">
                        {gettext("Combat sortie")}
                      </p>
                      <p class="mt-1 text-xs text-gray-400">
                        {gettext(
                          "The fleet will fight all ready defenders and surviving ships will return automatically."
                        )}
                      </p>
                    </div>
                  <% end %>
                <% end %>
              <% else %>
                <div class="rounded-xl border border-amber-700/60 bg-amber-950/30 px-3 py-3 text-sm text-amber-200">
                  {gettext(
                    "This mission type is visible as a placeholder for now. Only Colonization, Transport and Attack are currently playable."
                  )}
                </div>
              <% end %>
              
              <div class="flex flex-col-reverse gap-3 border-t border-gray-800 pt-4 sm:flex-row sm:justify-end">
                <button
                  type="button"
                  phx-click="close_send_mission_modal"
                  class="rounded-lg border border-gray-700 bg-gray-950 px-4 py-2.5 text-sm font-medium text-gray-200 transition hover:border-gray-500"
                >
                  {gettext("Cancel")}
                </button>
                <button
                  type="submit"
                  disabled={!mission_submit_enabled?(@mission_form, @selected_mission_fleet)}
                  class="rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-emerald-500 disabled:cursor-not-allowed disabled:bg-gray-700 disabled:text-gray-400"
                >
                  {gettext("Dispatch mission")}
                </button>
              </div>
            </form>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  def handle_event("create_fleet", params, socket) do
    case Fleets.create_fleet_for_user(socket.assigns.current_user.id, params) do
      {:ok, _fleet} ->
        {:noreply,
         socket
         |> assign_fleet_page()
         |> assign(:fleet_form, %{name: "", planet_id: "", admiral_card_id: ""})
         |> assign(:show_create_modal, false)
         |> put_flash(:success, gettext("Fleet created successfully."))
         |> assign(:fleet_error, nil)}

      {:error, :invalid_fleet} ->
        {:noreply,
         socket
         |> assign(:fleet_form, fleet_form_from_params(params))
         |> assign(:show_create_modal, true)
         |> assign(:fleet_error, gettext("Invalid fleet data."))}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:fleet_form, fleet_form_from_params(params))
         |> assign(:show_create_modal, true)
         |> assign(:fleet_error, gettext("Home planet not found."))}

      {:error, :card_not_owned} ->
        {:noreply,
         socket
         |> assign(:fleet_form, fleet_form_from_params(params))
         |> assign(:show_create_modal, true)
         |> assign(:fleet_error, gettext("You do not own that card."))}

      {:error, :card_already_assigned} ->
        {:noreply,
         socket
         |> assign(:fleet_form, fleet_form_from_params(params))
         |> assign(:show_create_modal, true)
         |> assign(
           :fleet_error,
           gettext("That admiral card is already assigned to another fleet.")
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:fleet_form, fleet_form_from_params(params))
         |> assign(:show_create_modal, true)
         |> assign(:fleet_error, gettext("Could not create the fleet."))}
    end
  end

  def handle_event("open_create_fleet_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:fleet_error, nil)}
  end

  def handle_event("close_create_fleet_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:fleet_error, nil)}
  end

  def handle_event("open_send_mission_modal", %{"fleet_id" => fleet_id}, socket) do
    user_id = socket.assigns.current_user.id
    fleet_id = String.to_integer(fleet_id)
    fleet = Enum.find(socket.assigns.fleets, &(&1.id == fleet_id))

    if fleet do
      can_colonize? = Fleets.ship_quantity(fleet, "colonizer") > 0
      default_mission = if can_colonize?, do: "colonization", else: "transport"

      mission_form = %{
        fleet_id: to_string(fleet_id),
        mission_type: default_mission,
        galaxy_id: "",
        system_id: "",
        target_planet_id: "",
        raw_materials: "0",
        microchips: "0",
        hydrogen: "0",
        food: "0",
        credits: "0"
      }

      {galaxies, systems, planets} = load_mission_target_options(fleet_id, user_id, mission_form)

      {:noreply,
       socket
       |> assign(:show_send_mission_modal, true)
       |> assign(:selected_mission_fleet, fleet)
       |> assign(:mission_error, nil)
       |> assign(:mission_galaxies, galaxies)
       |> assign(:mission_systems, systems)
       |> assign(:mission_targets, planets)
       |> assign(:mission_form, mission_form)}
    else
      {:noreply, put_flash(socket, :error, gettext("Fleet not found."))}
    end
  end

  def handle_event("close_send_mission_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_send_mission_modal, false)
     |> assign(:selected_mission_fleet, nil)
     |> assign(:mission_error, nil)
     |> assign(:mission_galaxies, [])
     |> assign(:mission_systems, [])
     |> assign(:mission_targets, [])
     |> assign(:mission_form, empty_mission_form())}
  end

  def handle_event("mission_form_changed", params, socket) do
    user_id = socket.assigns.current_user.id

    mission_form =
      params
      |> mission_form_from_params()
      |> clamp_transport_cargo(socket.assigns.selected_mission_fleet)

    fleet_id = parse_optional_int(mission_form.fleet_id)

    if fleet_id do
      {galaxies, systems, planets} = load_mission_target_options(fleet_id, user_id, mission_form)

      {:noreply,
       socket
       |> assign(:mission_form, mission_form)
       |> assign(:mission_galaxies, galaxies)
       |> assign(:mission_systems, systems)
       |> assign(:mission_targets, planets)
       |> assign(:mission_error, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_owned_transport_target", params, socket) do
    user_id = socket.assigns.current_user.id

    mission_form =
      socket.assigns.mission_form
      |> Map.merge(%{
        mission_type: "transport",
        galaxy_id: Map.get(params, "galaxy_id", ""),
        system_id: Map.get(params, "system_id", ""),
        target_planet_id: Map.get(params, "target_planet_id", "")
      })
      |> clamp_transport_cargo(socket.assigns.selected_mission_fleet)

    fleet_id = parse_optional_int(mission_form.fleet_id)
    {galaxies, systems, planets} = load_mission_target_options(fleet_id, user_id, mission_form)

    {:noreply,
     socket
     |> assign(:mission_form, mission_form)
     |> assign(:mission_galaxies, galaxies)
     |> assign(:mission_systems, systems)
     |> assign(:mission_targets, planets)
     |> assign(:mission_error, nil)}
  end

  def handle_event("max_transport_resource", %{"resource" => resource}, socket) do
    resource = parse_transport_resource(resource)

    mission_form =
      clamp_transport_cargo(socket.assigns.mission_form, socket.assigns.selected_mission_fleet)

    mission_form =
      if resource do
        current = parse_form_amount(Map.get(mission_form, resource))

        max_amount =
          current +
            transport_remaining_capacity(mission_form, socket.assigns.selected_mission_fleet)

        mission_form
        |> Map.put(resource, Integer.to_string(max_amount))
        |> clamp_transport_cargo(socket.assigns.selected_mission_fleet)
      else
        mission_form
      end

    {:noreply,
     socket
     |> assign(:mission_form, mission_form)
     |> assign(:mission_error, nil)}
  end

  def handle_event("send_mission", params, socket) do
    user_id = socket.assigns.current_user.id

    mission_form =
      params
      |> mission_form_from_params()
      |> clamp_transport_cargo(socket.assigns.selected_mission_fleet)

    fleet_id = parse_optional_int(mission_form.fleet_id)
    target_planet_id = parse_optional_int(mission_form.target_planet_id)

    cond do
      mission_form.mission_type not in ["colonization", "transport", "attack"] ->
        {:noreply,
         socket
         |> assign(:show_send_mission_modal, true)
         |> assign(:mission_form, mission_form)
         |> assign(:mission_error, gettext("That mission type is not implemented yet."))}

      is_nil(fleet_id) or is_nil(target_planet_id) ->
        {:noreply,
         socket
         |> assign(:show_send_mission_modal, true)
         |> assign(:mission_form, mission_form)
         |> assign(
           :mission_error,
           gettext("Choose galaxy, system and planet before dispatching.")
         )}

      true ->
        case dispatch_selected_mission(mission_form, fleet_id, user_id, target_planet_id) do
          {:ok, _mission} ->
            {:noreply,
             socket
             |> assign_fleet_page()
             |> assign(:show_send_mission_modal, false)
             |> assign(:selected_mission_fleet, nil)
             |> assign(:mission_error, nil)
             |> assign(:mission_galaxies, [])
             |> assign(:mission_systems, [])
             |> assign(:mission_targets, [])
             |> assign(:mission_form, empty_mission_form())
             |> put_flash(:success, dispatch_success_message(mission_form.mission_type))}

          {:error, reason} ->
            {galaxies, systems, planets} =
              load_mission_target_options(fleet_id, user_id, mission_form)

            {:noreply,
             socket
             |> assign(:show_send_mission_modal, true)
             |> assign(:mission_form, mission_form)
             |> assign(:mission_galaxies, galaxies)
             |> assign(:mission_systems, systems)
             |> assign(:mission_targets, planets)
             |> assign(:mission_error, mission_error_message(reason))}
        end
    end
  rescue
    ArgumentError ->
      {:noreply,
       socket
       |> assign(:show_send_mission_modal, true)
       |> assign(:mission_form, mission_form_from_params(params))
       |> assign(:mission_error, gettext("Invalid mission data."))}
  end

  def handle_event("toggle_user_menu", _, socket),
    do: {:noreply, update(socket, :show_user_menu, &(!&1))}

  def handle_event("close_menu", _, socket),
    do: {:noreply, assign(socket, :show_user_menu, false)}

  def handle_event("open_assign_admiral", %{"fleet_id" => fleet_id}, socket) do
    {:noreply, assign(socket, :assign_admiral_fleet_id, String.to_integer(fleet_id))}
  end

  def handle_event("cancel_assign_admiral", _, socket) do
    {:noreply, assign(socket, :assign_admiral_fleet_id, nil)}
  end

  def handle_event("assign_admiral_card", %{"fleet_id" => fleet_id, "card_id" => card_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Fleets.assign_admiral_to_fleet(
           String.to_integer(fleet_id),
           user_id,
           String.to_integer(card_id)
         ) do
      {:ok, _fleet} ->
        {:noreply,
         socket
         |> assign_fleet_page()
         |> put_flash(:success, gettext("Admiral assigned successfully."))
         |> assign(:assign_admiral_fleet_id, nil)}

      {:error, :card_not_owned} ->
        {:noreply, put_flash(socket, :error, gettext("You do not own that card."))}

      {:error, :card_already_assigned} ->
        {:noreply,
         put_flash(
           socket,
           :warning,
           gettext("That admiral card is already assigned to another fleet.")
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not assign admiral."))}
    end
  end

  def handle_event("unassign_admiral_card", %{"fleet_id" => fleet_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Fleets.unassign_admiral_from_fleet(String.to_integer(fleet_id), user_id) do
      {:ok, _fleet} ->
        {:noreply,
         socket
         |> assign_fleet_page()
         |> put_flash(:warning, gettext("Admiral unassigned."))
         |> assign(:assign_admiral_fleet_id, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not unassign admiral."))}
    end
  end

  def handle_info({:fleet_ship_built, _payload}, socket) do
    {:noreply, assign_fleet_page(socket)}
  end

  def handle_info({:fleet_mission_updated, _payload}, socket) do
    {:noreply, assign_fleet_page(socket)}
  end

  def handle_info(:mission_tick, socket) do
    new_socket = assign(socket, :now, DateTime.utc_now() |> DateTime.truncate(:second))

    if connected?(new_socket) do
      # Adaptive tick: 1s when active missions exist, 2s baseline (reduces polling load)
      # Note: active_missions_by_fleet only contains missions in active phases (outbound/colonizing/returning)
      has_active_missions = !Enum.empty?(new_socket.assigns[:active_missions_by_fleet] || %{})
      interval = if has_active_missions, do: 1_000, else: 2_000
      Process.send_after(self(), :mission_tick, interval)
    end

    {:noreply, new_socket}
  end

  defp assign_fleet_page(socket) do
    user_id = socket.assigns.current_user.id
    planets = Fleets.list_planets_for_user(user_id)
    fleets = Fleets.list_fleets_for_user(user_id)

    active_missions = Fleets.list_active_missions_for_fleets(Enum.map(fleets, & &1.id))

    socket
    |> assign(:planets, planets)
    |> assign(:fleets, fleets)
    |> assign(:active_missions_by_fleet, active_missions)
    |> assign(:fleet_metrics, fleet_metrics(fleets, planets))
    |> assign(:premium_access, premium_access?(socket.assigns.current_user))
    |> assign(:ship_catalog, Fleets.ship_catalog())
    |> assign(:user_admiral_cards, Cards.list_admiral_cards_for_user(user_id))
    |> assign_new(:fleet_form, fn -> %{name: "", planet_id: "", admiral_card_id: ""} end)
    |> assign_new(:fleet_error, fn -> nil end)
    |> assign_new(:show_create_modal, fn -> false end)
    |> assign_new(:show_send_mission_modal, fn -> false end)
    |> assign_new(:selected_mission_fleet, fn -> nil end)
    |> assign_new(:mission_error, fn -> nil end)
    |> assign_new(:mission_galaxies, fn -> [] end)
    |> assign_new(:mission_systems, fn -> [] end)
    |> assign_new(:mission_targets, fn -> [] end)
    |> assign_new(:mission_form, fn -> empty_mission_form() end)
    |> assign_new(:assign_admiral_fleet_id, fn -> nil end)
    |> assign(:show_user_menu, socket.assigns[:show_user_menu] || false)
  end

  defp assigned_card_ids_for_other_fleets(fleets, current_fleet_id) do
    fleets
    |> Enum.reject(&(&1.id == current_fleet_id))
    |> Enum.map(& &1.admiral_card_id)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp fleet_form_from_params(params) do
    %{
      name: Map.get(params, "name", ""),
      planet_id: Map.get(params, "planet_id", ""),
      admiral_card_id: Map.get(params, "admiral_card_id", "")
    }
  end

  defp mission_form_from_params(params) do
    %{
      fleet_id: Map.get(params, "fleet_id", ""),
      mission_type: Map.get(params, "mission_type", ""),
      galaxy_id: Map.get(params, "galaxy_id", ""),
      system_id: Map.get(params, "system_id", ""),
      target_planet_id: Map.get(params, "target_planet_id", ""),
      raw_materials: Map.get(params, "raw_materials", "0"),
      microchips: Map.get(params, "microchips", "0"),
      hydrogen: Map.get(params, "hydrogen", "0"),
      food: Map.get(params, "food", "0"),
      credits: Map.get(params, "credits", "0")
    }
  end

  defp empty_mission_form do
    %{
      fleet_id: "",
      mission_type: "",
      galaxy_id: "",
      system_id: "",
      target_planet_id: "",
      raw_materials: "0",
      microchips: "0",
      hydrogen: "0",
      food: "0",
      credits: "0"
    }
  end

  defp mission_options(nil), do: mission_options(%{ships: []})

  defp mission_options(fleet) do
    can_colonize? = Fleets.ship_quantity(fleet, "colonizer") > 0

    [
      %{
        value: "colonization",
        label:
          mission_option_label(
            gettext("Colonization"),
            can_colonize?,
            gettext("requires Colonizer")
          ),
        enabled?: can_colonize?
      },
      %{value: "transport", label: gettext("Transport"), enabled?: true},
      %{value: "attack", label: gettext("Attack"), enabled?: true},
      %{value: "trade_blockade", label: gettext("Trade Blockade"), enabled?: true},
      %{value: "planetary_defense", label: gettext("Planetary Defense"), enabled?: true},
      %{value: "orbital_bombardment", label: gettext("Orbital Bombardment"), enabled?: true}
    ]
  end

  defp mission_option_label(label, true, _suffix), do: label
  defp mission_option_label(label, false, suffix), do: "#{label} (#{suffix})"

  defp mission_galaxy_label(galaxy),
    do: "#{gettext("Galaxy")} #{galaxy.number} · #{galaxy.free_planets} #{gettext("targets")}"

  defp mission_system_label(system),
    do: "#{gettext("System")} #{system.number} · #{system.free_planets} #{gettext("targets")}"

  defp dispatch_selected_mission(
         %{mission_type: "colonization"},
         fleet_id,
         user_id,
         target_planet_id
       ) do
    Fleets.dispatch_colonization_mission_for_user(fleet_id, user_id, target_planet_id)
  end

  defp dispatch_selected_mission(
         %{mission_type: "transport"} = mission_form,
         fleet_id,
         user_id,
         target_planet_id
       ) do
    cargo =
      Map.take(mission_form, transport_resource_fields())
      |> Map.new(fn {resource, amount} -> {to_string(resource), amount} end)

    Fleets.dispatch_transport_mission_for_user(fleet_id, user_id, target_planet_id, cargo)
  end

  defp dispatch_selected_mission(%{mission_type: "attack"}, fleet_id, user_id, target_planet_id) do
    Fleets.dispatch_attack_mission_for_user(fleet_id, user_id, target_planet_id)
  end

  defp dispatch_success_message("attack"), do: gettext("Attack mission dispatched.")
  defp dispatch_success_message("transport"), do: gettext("Transport mission dispatched.")
  defp dispatch_success_message(_), do: gettext("Colonization mission dispatched.")

  defp transport_resource_fields, do: [:raw_materials, :microchips, :hydrogen, :food, :credits]

  defp transport_resource_label(:raw_materials), do: gettext("Raw Materials")
  defp transport_resource_label(:microchips), do: gettext("Microchips")
  defp transport_resource_label(:hydrogen), do: gettext("Hydrogen")
  defp transport_resource_label(:food), do: gettext("Food")
  defp transport_resource_label(:credits), do: gettext("Credits")

  defp parse_transport_resource(resource) when is_binary(resource) do
    Enum.find(transport_resource_fields(), &(to_string(&1) == resource))
  end

  defp parse_transport_resource(resource)
       when resource in [:raw_materials, :microchips, :hydrogen, :food, :credits],
       do: resource

  defp parse_transport_resource(_), do: nil

  defp planet_option_label(planet) do
    "#{mission_planet_name(planet)} #{planet_coordinates(planet)}"
  end

  defp mission_target_label(target) do
    name =
      case String.trim(target.name || "") do
        "" -> gettext("Unnamed Planet")
        value -> value
      end

    "#{name} [#{target.galaxy_number}:#{target.solar_system_number}:#{target.orbit_position}]"
  end

  defp mission_submit_enabled?(
         %{mission_type: "colonization", target_planet_id: target_planet_id},
         _fleet
       ), do: target_planet_id != ""

  defp mission_submit_enabled?(%{mission_type: "transport"} = form, fleet) do
    total = transport_cargo_total(form)
    form.target_planet_id != "" and total > 0 and total <= transport_cargo_capacity(fleet)
  end

  defp mission_submit_enabled?(
         %{mission_type: "attack", target_planet_id: target_planet_id},
         fleet
       ) do
    target_planet_id != "" and not is_nil(fleet) and Fleets.total_ships(fleet) > 0
  end

  defp mission_submit_enabled?(_form, _fleet), do: false

  defp owned_transport_targets(planets, nil), do: planets || []

  defp owned_transport_targets(planets, fleet) do
    Enum.reject(planets || [], &(&1.id == fleet.home_planet_id))
  end

  defp transport_cargo_capacity(nil), do: 0
  defp transport_cargo_capacity(fleet), do: Fleets.fleet_cargo_capacity(fleet)

  defp transport_cargo_total(form) do
    transport_resource_fields()
    |> Enum.reduce(0, fn field, acc -> acc + parse_form_amount(Map.get(form, field)) end)
  end

  defp transport_remaining_capacity(form, fleet) do
    max(transport_cargo_capacity(fleet) - transport_cargo_total(form), 0)
  end

  defp transport_resource_input_max(form, fleet, resource) do
    current = parse_form_amount(Map.get(form, resource))
    current + transport_remaining_capacity(form, fleet)
  end

  defp clamp_transport_cargo(%{mission_type: "transport"} = form, fleet) do
    capacity = transport_cargo_capacity(fleet)

    {form, _remaining} =
      Enum.reduce(transport_resource_fields(), {form, capacity}, fn field, {acc, remaining} ->
        amount = parse_form_amount(Map.get(acc, field))
        clamped = min(amount, max(remaining, 0))
        {Map.put(acc, field, Integer.to_string(clamped)), remaining - clamped}
      end)

    form
  end

  defp clamp_transport_cargo(form, _fleet), do: form

  defp parse_form_amount(value) when is_integer(value), do: max(value, 0)

  defp parse_form_amount(value) when is_binary(value) do
    case Integer.parse(value) do
      {amount, ""} when amount > 0 -> amount
      _ -> 0
    end
  end

  defp parse_form_amount(_), do: 0

  defp load_mission_target_options(fleet_id, user_id, %{
         mission_type: "colonization",
         galaxy_id: galaxy_id,
         system_id: system_id
       }) do
    galaxies =
      case Fleets.list_colonizable_galaxies_for_fleet(fleet_id, user_id) do
        {:ok, values} -> values
        _ -> []
      end

    systems =
      case parse_optional_int(galaxy_id) do
        nil ->
          []

        value ->
          case Fleets.list_colonizable_systems_for_fleet(fleet_id, user_id, value) do
            {:ok, values} -> values
            _ -> []
          end
      end

    planets =
      case parse_optional_int(system_id) do
        nil ->
          []

        value ->
          case Fleets.list_colonizable_planets_for_fleet(fleet_id, user_id, value) do
            {:ok, values} -> values
            _ -> []
          end
      end

    {galaxies, systems, planets}
  end

  defp load_mission_target_options(fleet_id, user_id, %{
         mission_type: "transport",
         galaxy_id: galaxy_id,
         system_id: system_id
       }) do
    galaxies =
      case Fleets.list_transportable_galaxies_for_fleet(fleet_id, user_id) do
        {:ok, values} -> values
        _ -> []
      end

    systems =
      case parse_optional_int(galaxy_id) do
        nil ->
          []

        value ->
          case Fleets.list_transportable_systems_for_fleet(fleet_id, user_id, value) do
            {:ok, values} -> values
            _ -> []
          end
      end

    planets =
      case parse_optional_int(system_id) do
        nil ->
          []

        value ->
          case Fleets.list_transportable_planets_for_fleet(fleet_id, user_id, value) do
            {:ok, values} -> values
            _ -> []
          end
      end

    {galaxies, systems, planets}
  end

  defp load_mission_target_options(fleet_id, user_id, %{
         mission_type: "attack",
         galaxy_id: galaxy_id,
         system_id: system_id
       }) do
    galaxies =
      case Fleets.list_attackable_galaxies_for_fleet(fleet_id, user_id) do
        {:ok, values} -> values
        _ -> []
      end

    systems =
      case parse_optional_int(galaxy_id) do
        nil ->
          []

        value ->
          case Fleets.list_attackable_systems_for_fleet(fleet_id, user_id, value) do
            {:ok, values} -> values
            _ -> []
          end
      end

    planets =
      case parse_optional_int(system_id) do
        nil ->
          []

        value ->
          case Fleets.list_attackable_planets_for_fleet(fleet_id, user_id, value) do
            {:ok, values} -> values
            _ -> []
          end
      end

    {galaxies, systems, planets}
  end

  defp load_mission_target_options(_fleet_id, _user_id, _mission_form), do: {[], [], []}

  defp fleet_metrics(fleets, planets) do
    %{
      total_fleets: length(fleets),
      total_ships: Enum.reduce(fleets, 0, fn fleet, acc -> acc + Fleets.total_ships(fleet) end),
      home_worlds: length(planets),
      ready_fleets: Enum.count(fleets, &(&1.status == "idle"))
    }
  end

  defp fleet_status_label(nil), do: gettext("Idle")
  defp fleet_status_label("idle"), do: gettext("Idle")
  defp fleet_status_label("outbound"), do: gettext("Outbound")
  defp fleet_status_label("colonizing"), do: gettext("Colonizing")
  defp fleet_status_label("returning"), do: gettext("Returning")
  defp fleet_status_label(status), do: translate_dynamic(status)

  defp fleet_status_badge_class(status) do
    base =
      "inline-flex rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide"

    cond do
      status in [nil, "idle"] ->
        base <> " border-emerald-700 bg-emerald-950/50 text-emerald-200"

      status == "outbound" ->
        base <> " border-cyan-700 bg-cyan-950/50 text-cyan-200"

      status == "colonizing" ->
        base <> " border-amber-700 bg-amber-950/50 text-amber-200"

      status == "returning" ->
        base <> " border-indigo-700 bg-indigo-950/50 text-indigo-200"

      true ->
        base <> " border-gray-700 bg-gray-900 text-gray-300"
    end
  end

  defp mission_error_message(:fleet_not_found), do: gettext("Fleet not found.")
  defp mission_error_message(:fleet_busy), do: gettext("Fleet is already on a mission.")

  defp mission_error_message(:active_fleet_limit_reached),
    do: gettext("You reached your active fleet mission limit.")

  defp mission_error_message(:target_not_found), do: gettext("Target planet not found.")

  defp mission_error_message(:target_unavailable),
    do: gettext("Target planet is already occupied.")

  defp mission_error_message(:target_colonizing),
    do: gettext("Target planet is currently being colonized.")

  defp mission_error_message(:colonizer_required),
    do: gettext("Fleet needs at least one Colonizer ship.")

  defp mission_error_message(:insufficient_hydrogen),
    do: gettext("Not enough hydrogen for the mission.")

  defp mission_error_message(:insufficient_resources),
    do: gettext("Not enough resources for cargo and fuel.")

  defp mission_error_message(:empty_cargo),
    do: gettext("Choose at least one resource to transport.")

  defp mission_error_message(:no_cargo_capacity), do: gettext("Fleet has no cargo capacity.")

  defp mission_error_message(:cargo_exceeds_capacity),
    do: gettext("Cargo exceeds fleet capacity.")

  defp mission_error_message(:invalid_cargo),
    do: gettext("Cargo amounts must be zero or greater.")

  defp mission_error_message(:empty_fleet), do: gettext("Fleet needs at least one ship.")
  defp mission_error_message(:no_route), do: gettext("No route found between origin and target.")
  defp mission_error_message(:invalid_target), do: gettext("Invalid target planet.")
  defp mission_error_message(_), do: gettext("Could not dispatch mission.")

  defp parse_optional_int(""), do: nil
  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(value) when is_integer(value), do: value
  defp parse_optional_int(value) when is_binary(value), do: String.to_integer(value)

  defp fleet_power(fleet, ship_catalog) do
    ship_catalog
    |> Enum.reduce(0, fn ship, acc ->
      quantity = Fleets.ship_quantity(fleet, ship.type)
      acc + quantity * ship.attack + quantity * ship.hull
    end)
  end

  defp mission_progress_percent(mission, now) do
    {start_at, end_at} = mission_time_window(mission, now)

    total_seconds = max(DateTime.diff(end_at, start_at, :second), 1)
    elapsed_seconds = DateTime.diff(now, start_at, :second)

    elapsed_seconds
    |> max(0)
    |> min(total_seconds)
    |> Kernel./(total_seconds)
    |> Kernel.*(100)
    |> Float.round(1)
  end

  defp mission_progress_label(mission, now) do
    percent = mission_progress_percent(mission, now)
    "#{percent}%"
  end

  defp mission_progress_title(mission, now) do
    case mission_display_phase(mission, now) do
      :outbound -> gettext("Travel progress")
      :colonizing -> gettext("Building colony")
      :returning -> gettext("Return progress")
      _ -> gettext("Travel progress")
    end
  end

  defp mission_eta_label(mission, now) do
    case mission_display_phase(mission, now) do
      :colonizing -> gettext("Completion in")
      _ -> gettext("Arrival in")
    end
  end

  defp mission_origin_name(%{phase: "returning"} = mission),
    do: mission_planet_name(mission.target_planet)

  defp mission_origin_name(mission), do: mission_planet_name(mission.origin_planet)

  defp mission_destination_name(%{phase: "returning"} = mission),
    do: mission_planet_name(mission.origin_planet)

  defp mission_destination_name(%{phase: "colonizing"} = mission),
    do: mission_planet_name(mission.target_planet)

  defp mission_destination_name(mission), do: mission_planet_name(mission.target_planet)

  defp mission_remaining_label(mission, now) do
    {_start_at, end_at} = mission_time_window(mission, now)
    remaining = max(DateTime.diff(end_at, now, :second), 0)

    if remaining == 0 do
      mission_completed_label(mission, now)
    else
      format_duration(remaining)
    end
  end

  defp mission_completed_label(mission, now) do
    case mission_display_phase(mission, now) do
      :colonizing -> gettext("Colony ready")
      _ -> gettext("Arrived")
    end
  end

  defp mission_time_window(mission, now) do
    case mission_display_phase(mission, now) do
      :outbound ->
        arrival_at = mission.outbound_arrival_at
        {DateTime.add(arrival_at, -mission.outbound_travel_seconds, :second), arrival_at}

      :colonizing ->
        {start_at, end_at} = mission_colonizing_window(mission)
        {start_at, end_at}

      :returning ->
        arrival_at = mission.return_arrival_at
        {DateTime.add(arrival_at, -mission.return_travel_seconds, :second), arrival_at}

      _ ->
        {mission.inserted_at, mission.inserted_at}
    end
  end

  defp mission_colonizing_window(
         %{phase: "colonizing", colonization_complete_at: complete_at} = mission
       )
       when not is_nil(complete_at) do
    {DateTime.add(complete_at, -mission.colonization_seconds, :second), complete_at}
  end

  defp mission_colonizing_window(%{outbound_arrival_at: outbound_arrival_at} = mission) do
    end_at = DateTime.add(outbound_arrival_at, mission.colonization_seconds, :second)
    {outbound_arrival_at, end_at}
  end

  defp mission_display_phase(
         %{
           mission_type: "colonization",
           phase: "outbound",
           outbound_arrival_at: outbound_arrival_at
         },
         now
       )
       when not is_nil(outbound_arrival_at) do
    if DateTime.compare(now, outbound_arrival_at) in [:eq, :gt] do
      # If worker delivery is delayed, show colonization progress instead of an outbound bar stuck at 100%.
      :colonizing
    else
      :outbound
    end
  end

  defp mission_display_phase(%{phase: "outbound", outbound_arrival_at: outbound_arrival_at}, _now)
       when not is_nil(outbound_arrival_at) do
    :outbound
  end

  defp mission_display_phase(%{phase: "outbound"}, _now), do: :outbound
  defp mission_display_phase(%{phase: "colonizing"}, _now), do: :colonizing
  defp mission_display_phase(%{phase: "returning"}, _now), do: :returning
  defp mission_display_phase(_mission, _now), do: :outbound

  defp mission_planet_name(nil), do: gettext("Unknown")

  defp mission_planet_name(planet) do
    case String.trim(planet.name || "") do
      "" -> gettext("Unnamed Planet")
      value -> value
    end
  end

  defp planet_coordinates(%{
         solar_system: %{galaxy: %{number: galaxy_number}, number: system_number},
         orbit_position: orbit_position
       }) do
    "[#{galaxy_number}:#{system_number}:#{orbit_position}]"
  end

  defp planet_coordinates(%{
         solar_system: %{number: system_number},
         orbit_position: orbit_position
       }) do
    "[?:#{system_number}:#{orbit_position}]"
  end

  defp planet_coordinates(_planet), do: "[?:?:?]"

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)
  defp format_number(value), do: value |> parse_form_amount() |> Integer.to_string()

  defp format_duration(total_seconds) do
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    seconds = rem(total_seconds, 60)

    if hours > 0 do
      :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, seconds]) |> to_string()
    else
      :io_lib.format("~2..0B:~2..0B", [minutes, seconds]) |> to_string()
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

  defp translate_dynamic(msgid), do: Gettext.gettext(NexusDownfallWeb.Gettext, msgid)
end
