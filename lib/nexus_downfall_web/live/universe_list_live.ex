defmodule NexusDownfallWeb.UniverseListLive do
  @moduledoc "Lists open universes the player can join."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Universe
  alias NexusDownfall.Accounts

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#030712] text-gray-100">
      <.topbar
        current_user={@current_user}
        show_user_menu={@show_user_menu}
        show_game_nav={false}
        logo_path={~p"/universes"}
      />
      <main class="relative min-h-[calc(100vh-2.5rem)] overflow-hidden px-4 py-8 sm:px-8 lg:px-12">
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_15%_20%,rgba(34,211,238,0.24),transparent_35%),radial-gradient(circle_at_88%_15%,rgba(59,130,246,0.26),transparent_28%),radial-gradient(circle_at_60%_90%,rgba(16,185,129,0.14),transparent_30%)]" />
        <div class="relative mx-auto max-w-6xl space-y-8">
          <section class="rounded-2xl border border-cyan-500/25 bg-[#071020]/85 p-6 shadow-[0_25px_80px_rgba(8,47,73,0.45)] backdrop-blur">
            <p class="text-[11px] font-semibold uppercase tracking-[0.35em] text-cyan-300/80">
              {gettext("Universe Selection")}
            </p>

            <h1 class="mt-3 text-3xl font-black uppercase tracking-[0.08em] text-cyan-100 sm:text-4xl">
              {gettext("Deploy Your Command")}
            </h1>

            <p class="mt-3 max-w-3xl text-sm leading-relaxed text-cyan-100/80 sm:text-base">
              {gettext(
                "Welcome, %{name}. Choose where your account will begin the war campaign. Each universe has a different population pressure and expansion space.",
                name: @current_user.account_name || @current_user.email
              )}
            </p>
          </section>

          <%= if @universes == [] do %>
            <section class="rounded-2xl border border-gray-800 bg-gray-900/80 p-10 text-center text-gray-300">
              <p class="text-lg font-semibold text-white">
                {gettext("No open universes right now.")}
              </p>

              <p class="mt-2 text-sm text-gray-400">
                {gettext("Check back soon. New battlefronts open regularly.")}
              </p>
            </section>
          <% else %>
            <section class="grid gap-5 lg:grid-cols-2">
              <%= for universe <- @universes do %>
                <% stats = Map.get(@stats_by_universe_id, universe.id, default_stats()) %> <% joined? =
                  MapSet.member?(@joined_ids, universe.id) %>
                <article class="group relative overflow-hidden rounded-2xl border border-cyan-500/20 bg-[#091427]/90 p-5 shadow-[0_18px_48px_rgba(8,47,73,0.35)] transition hover:-translate-y-0.5 hover:border-cyan-400/40 hover:shadow-[0_28px_65px_rgba(8,47,73,0.5)]">
                  <div class="pointer-events-none absolute right-0 top-0 h-24 w-24 rounded-full bg-cyan-400/15 blur-2xl" />
                  <div class="relative">
                    <p class="text-[10px] uppercase tracking-[0.28em] text-cyan-300/75">
                      {gettext("Universe")}
                    </p>

                    <h2 class="mt-2 text-xl font-extrabold text-white">{universe.name}</h2>

                    <p class="mt-1 text-xs text-gray-400">ID: {universe.slug}</p>

                    <div class="mt-4 grid grid-cols-3 gap-3">
                      <div class="rounded-xl border border-cyan-500/20 bg-cyan-500/8 p-3">
                        <p class="text-[10px] uppercase tracking-[0.2em] text-cyan-300/70">
                          {gettext("Galaxies")}
                        </p>

                        <p class="mt-1 text-lg font-bold text-cyan-100">{stats.galaxies}</p>
                      </div>

                      <div class="rounded-xl border border-emerald-500/20 bg-emerald-500/8 p-3">
                        <p class="text-[10px] uppercase tracking-[0.2em] text-emerald-300/80">
                          {gettext("Free planets")}
                        </p>

                        <p class="mt-1 text-lg font-bold text-emerald-200">{stats.free_planets}</p>
                      </div>

                      <div class="rounded-xl border border-orange-500/20 bg-orange-500/8 p-3">
                        <p class="text-[10px] uppercase tracking-[0.2em] text-orange-300/75">
                          {gettext("Players")}
                        </p>

                        <p class="mt-1 text-lg font-bold text-orange-200">{stats.players}</p>
                      </div>
                    </div>

                    <div class="mt-5 flex flex-wrap items-center gap-3">
                      <%= if joined? do %>
                        <.link
                          navigate={~p"/dashboard"}
                          class="inline-flex items-center rounded-lg border border-emerald-500/40 bg-emerald-600/40 px-4 py-2 text-sm font-semibold text-emerald-100 transition hover:bg-emerald-500/50"
                        >
                          {gettext("Open Command Dashboard")}
                        </.link>
                      <% else %>
                        <.link
                          navigate={~p"/universes/#{universe.slug}/join"}
                          class="inline-flex items-center rounded-lg border border-cyan-400/40 bg-cyan-500/30 px-4 py-2 text-sm font-semibold text-cyan-50 transition hover:bg-cyan-400/40"
                        >
                          {gettext("Join the Army")}
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </article>
              <% end %>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    universes = Universe.list_open_universes()
    memberships = Accounts.list_universe_memberships(socket.assigns.current_user.id)
    joined_ids = MapSet.new(memberships, & &1.universe_id)

    stats_by_universe_id =
      universes
      |> Enum.map(fn universe ->
        galaxy_stats = Universe.list_galaxy_join_stats(universe)

        stats = %{
          galaxies: length(galaxy_stats),
          players: galaxy_stats |> Enum.reduce(0, fn item, acc -> acc + item.users_count end),
          occupied_planets:
            galaxy_stats |> Enum.reduce(0, fn item, acc -> acc + item.occupied_planets end),
          free_planets:
            galaxy_stats |> Enum.reduce(0, fn item, acc -> acc + item.free_planets end)
        }

        {universe.id, stats}
      end)
      |> Map.new()

    {:ok,
     assign(socket,
       universes: universes,
       joined_ids: joined_ids,
       stats_by_universe_id: stats_by_universe_id,
       show_user_menu: false
     )}
  end

  def handle_event("toggle_user_menu", _, socket),
    do: {:noreply, update(socket, :show_user_menu, &(!&1))}

  defp default_stats do
    %{galaxies: 0, players: 0, occupied_planets: 0, free_planets: 0}
  end
end
