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
    end

    {:ok, assign_fleet_page(socket)}
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
                <p class="text-[10px] uppercase tracking-[0.22em] text-cyan-300/80"><%= gettext("Fleet Operations") %></p>
                <h1 class="mt-1 text-xl font-bold text-white md:text-2xl"><%= gettext("Fleet Management") %></h1>
                <p class="mt-1 text-xs text-cyan-100/80 md:text-sm"><%= gettext("Monitor each fleet, inspect every ship class and prepare mission dispatches.") %></p>
              </div>

              <div class="grid grid-cols-2 gap-2 text-right md:grid-cols-4">
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Fleets") %></p>
                  <p class="text-lg font-bold text-cyan-200"><%= @fleet_metrics.total_fleets %></p>
                </div>
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Ships") %></p>
                  <p class="text-lg font-bold text-cyan-200"><%= @fleet_metrics.total_ships %></p>
                </div>
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Worlds") %></p>
                  <p class="text-lg font-bold text-cyan-200"><%= @fleet_metrics.home_worlds %></p>
                </div>
                <div class="rounded-lg border border-cyan-500/30 bg-[#04101d]/80 px-3 py-2">
                  <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Ready") %></p>
                  <p class="text-lg font-bold text-emerald-300"><%= @fleet_metrics.ready_fleets %></p>
                </div>
              </div>
            </div>
          </section>

          <div class="grid gap-4 xl:grid-cols-[280px_minmax(0,1fr)]">
            <aside class="space-y-4 xl:sticky xl:top-4 xl:self-start">
              <section class="overflow-hidden rounded-2xl border border-cyan-500/25 bg-[#0a1528]/95 shadow-[0_18px_44px_rgba(2,8,22,0.62)]">
                <div class="border-b border-cyan-500/15 bg-[linear-gradient(170deg,rgba(8,145,178,0.22),rgba(8,145,178,0.03))] px-4 py-3">
                  <h2 class="text-lg font-bold text-white"><%= gettext("Fleet Management") %></h2>
                  <p class="mt-1 text-xs text-cyan-100/80"><%= gettext("Create and organize your operational fleets.") %></p>
                </div>

                <div class="p-4">
                  <button phx-click="open_create_fleet_modal" class="w-full rounded-xl bg-[linear-gradient(90deg,#0ea5e9,#22d3ee)] px-4 py-2.5 text-sm font-semibold text-white shadow-[0_8px_24px_rgba(14,165,233,0.45)] transition hover:brightness-110">
                    + <%= gettext("New Fleet") %>
                  </button>

                  <div class="mt-3 grid grid-cols-2 gap-2">
                    <div class="rounded-lg border border-cyan-500/20 bg-[#060d18]/70 px-3 py-2">
                      <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Fleets") %></p>
                      <p class="text-base font-bold text-cyan-200"><%= @fleet_metrics.total_fleets %></p>
                    </div>
                    <div class="rounded-lg border border-cyan-500/20 bg-[#060d18]/70 px-3 py-2">
                      <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Ships") %></p>
                      <p class="text-base font-bold text-cyan-200"><%= @fleet_metrics.total_ships %></p>
                    </div>
                  </div>

                  <div class="mt-4 rounded-xl border border-cyan-500/20 bg-[#050f1d]/80 p-3">
                    <div class="mb-2 flex items-center justify-between gap-2">
                      <h3 class="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300"><%= gettext("Fleet Filters") %></h3>
                      <span class="rounded-full border border-amber-600/60 bg-amber-900/30 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-300"><%= gettext("PRO") %></span>
                    </div>

                    <div class={[
                      "space-y-2 transition",
                      if(!@premium_access, do: "pointer-events-none opacity-45 grayscale-[0.35]", else: "opacity-100")
                    ]}>
                      <div>
                        <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500"><%= gettext("Mission") %></label>
                        <select class="w-full rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-xs text-gray-300">
                          <option><%= gettext("All missions") %></option>
                        </select>
                      </div>

                      <div>
                        <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500"><%= gettext("Planet") %></label>
                        <select class="w-full rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-xs text-gray-300">
                          <option><%= gettext("All planets") %></option>
                        </select>
                      </div>

                      <div>
                        <label class="mb-1 block text-[11px] uppercase tracking-wide text-gray-500"><%= gettext("Search") %></label>
                        <input type="text" class="w-full rounded-lg border border-gray-700 bg-[#060d18] px-2.5 py-2 text-xs text-gray-300" placeholder={gettext("Fleet name...")} />
                      </div>
                    </div>

                    <button :if={!@premium_access} type="button" class="mt-3 w-full rounded-lg border border-amber-500/70 bg-amber-900/35 px-3 py-2 text-xs font-semibold uppercase tracking-wide text-amber-200 transition hover:bg-amber-900/55">
                      <%= gettext("Unlock with PRO") %>
                    </button>
                  </div>

                  <p class="mt-3 text-[11px] text-gray-500"><%= gettext("Advanced filters are visible but restricted to PRO commanders.") %></p>
                </div>
              </section>
            </aside>

            <section class="rounded-2xl border border-cyan-500/20 bg-[#081225]/90 p-3 shadow-[0_18px_44px_rgba(2,8,22,0.62)] md:p-4">
              <div class="mb-3 hidden items-center gap-2 rounded-xl border border-cyan-500/15 bg-[#050e1c]/90 px-3 py-2 text-[10px] font-semibold uppercase tracking-wider text-cyan-300/70 xl:flex">
                <div class="w-[72px] shrink-0"><%= gettext("Admiral") %></div>
                <div class="flex-1 grid grid-cols-[minmax(0,1fr)_200px_180px_auto] gap-2 items-center">
                  <span><%= gettext("Fleet") %></span>
                  <span><%= gettext("Location") %></span>
                  <span><%= gettext("Mission") %></span>
                  <span class="text-right"><%= gettext("Actions") %></span>
                </div>
              </div>

              <%= if @fleets == [] do %>
                <div class="rounded-2xl border border-dashed border-cyan-600/30 bg-[#060d18]/80 px-6 py-12 text-center">
                  <p class="text-lg font-semibold text-white"><%= gettext("No fleets registered yet.") %></p>
                  <p class="mx-auto mt-2 max-w-xl text-sm text-gray-400"><%= gettext("Create a fleet to start assigning ships from the spaceport queue.") %></p>
                  <button phx-click="open_create_fleet_modal" class="mt-5 rounded-xl bg-cyan-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-cyan-500"><%= gettext("Create new fleet") %></button>
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
                              <p class="text-center text-[9px] font-bold leading-tight text-white drop-shadow"><%= fleet.admiral_card.name %></p>
                              <button
                                type="button"
                                phx-click="open_assign_admiral"
                                phx-value-fleet_id={fleet.id}
                                class="mt-1 w-full rounded border border-cyan-500/50 bg-cyan-900/50 px-1 py-0.5 text-[8px] font-semibold uppercase tracking-wide text-cyan-200 transition hover:bg-cyan-800/60"
                              >
                                <%= gettext("Change") %>
                              </button>
                            </div>
                          <% else %>
                            <%!-- No admiral - show placeholder and assign button --%>
                            <div class="absolute inset-0 flex flex-col items-center justify-center gap-2 p-2">
                              <div class="flex h-10 w-10 items-center justify-center rounded-full border border-gray-700/50 bg-gray-900/50">
                                <span class="text-2xl opacity-20">★</span>
                              </div>
                              <p class="text-center text-[8px] text-gray-600"><%= gettext("No admiral") %></p>
                              <button
                                type="button"
                                phx-click="open_assign_admiral"
                                phx-value-fleet_id={fleet.id}
                                class="w-full rounded border border-cyan-600/50 bg-cyan-900/30 px-1 py-1 text-[8px] font-semibold uppercase tracking-wide text-cyan-300 transition hover:bg-cyan-800/40"
                              >
                                <%= gettext("Assign") %>
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
                                <h3 class="truncate text-sm font-bold text-white"><%= fleet.name %></h3>
                                <span class={fleet_status_badge_class(fleet.status)}><%= fleet_status_label(fleet.status) %></span>
                              </div>
                            </div>

                            <div class="rounded-lg border border-cyan-500/15 bg-[#050f1d]/70 px-3 py-2">
                              <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Planet") %></p>
                              <p class="truncate text-sm font-semibold text-white"><%= fleet.home_planet.name %></p>
                              <p class="text-[11px] text-gray-400"><%= gettext("System") %> <%= fleet.home_planet.solar_system.number %></p>
                            </div>

                            <div class="rounded-lg border border-cyan-500/15 bg-[#050f1d]/70 px-3 py-2">
                              <p class="text-[10px] uppercase tracking-wide text-gray-500"><%= gettext("Current mission") %></p>
                              <p class="text-sm font-semibold text-cyan-200"><%= fleet_status_label(fleet.status) %></p>
                              <p class="text-[11px] text-gray-400"><%= gettext("Power") %>: <%= fleet_power(fleet, @ship_catalog) %></p>
                            </div>

                            <div class="flex items-center justify-end">
                              <button type="button" class="rounded-lg border border-emerald-500/60 bg-emerald-900/35 px-3 py-2 text-xs font-semibold uppercase tracking-wide text-emerald-200 transition hover:bg-emerald-800/45">
                                <%= gettext("Send mission") %>
                              </button>
                            </div>
                          </div>

                          <%!-- Row 2: ship manifest - full width below fleet info --%>
                          <div class="rounded-lg border border-cyan-500/10 bg-[#030a15]/60 p-2">
                            <p class="mb-1.5 text-[9px] uppercase tracking-widest text-gray-600"><%= gettext("Ship Manifest") %></p>
                            <div class="flex flex-wrap gap-1.5">
                              <%= for ship <- @ship_catalog do %>
                                <div class="flex min-w-[90px] items-center gap-1.5 rounded-lg border border-cyan-500/15 bg-[#030914]/85 px-2 py-1">
                                  <img src={"/images/ships/#{ship.type}.svg"} onerror="this.style.display='none'" alt={translate_dynamic(ship.name)} class="h-6 w-6 rounded bg-black/30 p-0.5 object-contain" draggable="false" />
                                  <div class="min-w-0">
                                    <p class="truncate text-[9px] text-gray-400"><%= translate_dynamic(ship.name) %></p>
                                    <p class="text-xs font-bold leading-none text-white"><%= Fleets.ship_quantity(fleet, ship.type) %></p>
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
                              <p class="text-xs font-semibold uppercase tracking-wider text-cyan-300"><%= gettext("Choose an admiral from your deck") %></p>
                              <button
                                type="button"
                                phx-click="cancel_assign_admiral"
                                class="rounded p-0.5 text-gray-500 transition hover:text-gray-300"
                              >✕</button>
                            </div>
                            <div class="flex flex-1 flex-wrap items-start gap-3 overflow-y-auto p-3">
                              <% assigned_card_ids = assigned_card_ids_for_other_fleets(@fleets, fleet.id) %>
                              <button
                                type="button"
                                phx-click="unassign_admiral_card"
                                phx-value-fleet_id={fleet.id}
                                class="group flex w-[110px] flex-col overflow-hidden rounded-xl border border-amber-400/50 bg-[#0f1218] transition hover:border-amber-300 hover:shadow-[0_0_16px_rgba(250,204,21,0.2)]"
                              >
                                <div class="flex h-28 w-full items-center justify-center bg-[#090c12]">
                                  <span class="text-5xl font-black leading-none text-amber-300">✕</span>
                                </div>
                                <div class="p-2">
                                  <p class="text-center text-[10px] font-bold text-amber-100"><%= gettext("Unassign admiral") %></p>
                                </div>
                              </button>

                              <%= if @user_admiral_cards == [] do %>
                                <p class="text-sm text-gray-500"><%= gettext("No admiral cards in your deck.") %></p>
                              <% else %>
                                <%= for uc <- @user_admiral_cards do %>
                                  <% assigned_elsewhere = MapSet.member?(assigned_card_ids, uc.card_id) %>
                                  <button
                                    type="button"
                                    disabled={assigned_elsewhere}
                                    title={if assigned_elsewhere, do: gettext("Already assigned to another fleet."), else: nil}
                                    phx-click={if assigned_elsewhere, do: nil, else: "assign_admiral_card"}
                                    phx-value-fleet_id={fleet.id}
                                    phx-value-card_id={uc.card_id}
                                    class={[
                                      "group flex w-[110px] flex-col overflow-hidden rounded-xl border bg-[#050f1d] transition",
                                      if(assigned_elsewhere,
                                        do: "cursor-not-allowed border-gray-600/40 opacity-45 grayscale",
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
                                          if(assigned_elsewhere, do: "", else: "group-hover:scale-105")
                                        ]}
                                        draggable="false"
                                      />
                                    </div>
                                    <div class="p-2">
                                      <p class="text-center text-[10px] font-bold text-white"><%= uc.card.name %></p>
                                      <p class="text-center text-[8px] capitalize text-cyan-300/70"><%= uc.card.rarity %></p>
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

      <.modal :if={@show_create_modal} id="create-fleet-modal" show on_cancel={JS.push("close_create_fleet_modal")}>
        <div class="relative overflow-hidden rounded-2xl border border-cyan-500/30 bg-[#0c1422]">
          <div class="relative h-32 overflow-hidden">
            <img src="/images/planet-images/barraks.jpg" class="absolute inset-0 h-full w-full object-cover" draggable="false" />
            <div class="absolute inset-0 bg-gradient-to-b from-black/20 via-black/50 to-black/90" />
            <div class="absolute bottom-3 left-4">
              <h2 id="create-fleet-modal-title" class="text-xl font-bold text-white"><%= gettext("Create fleet") %></h2>
              <p id="create-fleet-modal-description" class="mt-1 text-xs text-gray-300"><%= gettext("Create a named fleet, assign its home planet and optionally an admiral card.") %></p>
            </div>
          </div>

          <div class="space-y-4 p-5">
            <%= if @fleet_error do %>
              <div class="rounded-xl border border-red-700 bg-red-950/40 px-3 py-2 text-sm text-red-300"><%= @fleet_error %></div>
            <% end %>

            <form phx-submit="create_fleet" class="space-y-4">
              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500"><%= gettext("Fleet name") %></label>
                <input type="text" name="name" value={@fleet_form.name} placeholder={gettext("Choose a name for your new fleet")} class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white placeholder:text-gray-600 focus:border-cyan-500 focus:outline-none" />
              </div>

              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500"><%= gettext("Home planet") %></label>
                <select name="planet_id" class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none">
                  <option value=""><%= gettext("Select one of your planets") %></option>
                  <%= for planet <- @planets do %>
                    <option value={planet.id} selected={to_string(planet.id) == @fleet_form.planet_id}><%= planet_option_label(planet) %></option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="mb-2 block text-xs font-semibold uppercase tracking-wider text-gray-500"><%= gettext("Assigned admiral") %></label>
                <select name="admiral_card_id" class="w-full rounded-xl border border-gray-700 bg-[#060d18] px-3 py-2.5 text-sm text-white focus:border-cyan-500 focus:outline-none">
                  <option value=""><%= gettext("No admiral") %></option>
                  <%= for uc <- @user_admiral_cards do %>
                    <option value={uc.card_id} selected={to_string(uc.card_id) == @fleet_form.admiral_card_id}><%= uc.card.name %></option>
                  <% end %>
                </select>
              </div>

              <div class="flex flex-col-reverse gap-3 border-t border-gray-800 pt-4 sm:flex-row sm:justify-end">
                <button type="button" phx-click="close_create_fleet_modal" class="rounded-lg border border-gray-700 bg-gray-950 px-4 py-2.5 text-sm font-medium text-gray-200 transition hover:border-gray-500"><%= gettext("Cancel") %></button>
                <button type="submit" class="rounded-lg bg-cyan-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-cyan-500"><%= gettext("Create fleet") %></button>
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
         |> assign(:fleet_error, gettext("That admiral card is already assigned to another fleet."))}

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

  def handle_event("toggle_user_menu", _, socket), do: {:noreply, update(socket, :show_user_menu, &(!&1))}
  def handle_event("close_menu", _, socket), do: {:noreply, assign(socket, :show_user_menu, false)}

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
         put_flash(socket, :warning, gettext("That admiral card is already assigned to another fleet."))}

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

  defp assign_fleet_page(socket) do
    user_id = socket.assigns.current_user.id
    planets = Fleets.list_planets_for_user(user_id)
    fleets = Fleets.list_fleets_for_user(user_id)

    socket
    |> assign(:planets, planets)
    |> assign(:fleets, fleets)
    |> assign(:fleet_metrics, fleet_metrics(fleets, planets))
    |> assign(:premium_access, premium_access?(socket.assigns.current_user))
    |> assign(:ship_catalog, Fleets.ship_catalog())
    |> assign(:user_admiral_cards, Cards.list_admiral_cards_for_user(user_id))
    |> assign_new(:fleet_form, fn -> %{name: "", planet_id: "", admiral_card_id: ""} end)
    |> assign_new(:fleet_error, fn -> nil end)
    |> assign_new(:show_create_modal, fn -> false end)
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

  defp planet_option_label(planet) do
    "#{planet.name} - #{gettext("System")} #{planet.solar_system.number}"
  end

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
  defp fleet_status_label(status), do: translate_dynamic(status)

  defp fleet_status_badge_class(status) do
    base = "inline-flex rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide"

    if status in [nil, "idle"] do
      base <> " border-emerald-700 bg-emerald-950/50 text-emerald-200"
    else
      base <> " border-gray-700 bg-gray-900 text-gray-300"
    end
  end

  defp fleet_power(fleet, ship_catalog) do
    ship_catalog
    |> Enum.reduce(0, fn ship, acc ->
      quantity = Fleets.ship_quantity(fleet, ship.type)
      acc + quantity * ship.attack + quantity * ship.hull
    end)
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
