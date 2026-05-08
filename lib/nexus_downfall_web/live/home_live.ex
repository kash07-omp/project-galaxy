defmodule NexusDownfallWeb.HomeLive do
  @moduledoc "Sci-fi home and marketing page for Nexus: Downfall."

  use NexusDownfallWeb, :live_view

  on_mount {NexusDownfallWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Nexus: Downfall")
     |> assign(:show_user_menu, false)}
  end

  @impl true
  def handle_event("toggle_user_menu", _params, socket) do
    {:noreply, update(socket, :show_user_menu, &(!&1))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#020817] text-gray-100">
      <%= if @current_user do %>
        <.topbar
          current_user={@current_user}
          show_user_menu={@show_user_menu}
          active_tab="overview"
          show_game_nav={false}
          logo_path={~p"/dashboard"}
        />
      <% else %>
        <nav class="flex h-10 items-center justify-between border-b border-cyan-900/60 bg-[#041127]/90 px-4 backdrop-blur sm:px-6">
          <div class="flex items-center gap-2">
            <span class="text-cyan-300 text-sm font-black">NX</span>
            <span class="text-xs font-extrabold uppercase tracking-[0.24em] text-cyan-100">Nexus: Downfall</span>
          </div>

          <div class="flex items-center gap-2 text-xs font-semibold">
            <.link navigate={~p"/users/log_in"} class="rounded border border-cyan-400/35 px-3 py-1 text-cyan-200 hover:bg-cyan-500/20">
              <%= gettext("Log in") %>
            </.link>
            <.link navigate={~p"/users/register"} class="rounded border border-emerald-400/35 bg-emerald-500/15 px-3 py-1 text-emerald-100 hover:bg-emerald-400/30">
              <%= gettext("Register") %>
            </.link>
          </div>
        </nav>
      <% end %>

      <main class="relative min-h-[calc(100vh-2.5rem)] overflow-hidden">
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_18%_20%,rgba(45,212,191,0.2),transparent_35%),radial-gradient(circle_at_84%_22%,rgba(59,130,246,0.24),transparent_32%),radial-gradient(circle_at_50%_88%,rgba(16,185,129,0.15),transparent_30%)]" />
        <div class="pointer-events-none absolute left-[-12rem] top-[18%] h-72 w-72 rounded-full bg-cyan-400/20 blur-3xl" />
        <div class="pointer-events-none absolute right-[-10rem] top-[42%] h-72 w-72 rounded-full bg-blue-500/20 blur-3xl" />

        <section class="relative mx-auto max-w-6xl px-4 pb-12 pt-10 sm:px-8 lg:px-12 lg:pt-14">
          <div class="grid gap-8 lg:grid-cols-[1.3fr,1fr] lg:items-center">
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.34em] text-cyan-300/85"><%= gettext("Browser MMORTS") %></p>
              <h1 class="mt-4 text-4xl font-black uppercase leading-tight tracking-[0.06em] text-cyan-100 sm:text-5xl lg:text-6xl">
                <%= gettext("Rule The Collapse.") %>
                <span class="block text-emerald-300"><%= gettext("Survive The Universe.") %></span>
              </h1>
              <p class="mt-5 max-w-2xl text-sm leading-relaxed text-cyan-100/80 sm:text-base">
                <%= gettext("Expand from one fragile world to a multi-system empire. Build planets, launch fleets, manage diplomacy and adapt in real time while rival factions fight for control of each galaxy lane.") %>
              </p>

              <div class="mt-7 flex flex-wrap items-center gap-3">
                <%= if @current_user do %>
                  <.link navigate={~p"/universes"} class="rounded-lg border border-cyan-300/50 bg-cyan-400/20 px-4 py-2 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/35">
                    <%= gettext("Join A Universe") %>
                  </.link>
                  <.link navigate={~p"/dashboard"} class="rounded-lg border border-emerald-300/45 bg-emerald-400/15 px-4 py-2 text-sm font-semibold text-emerald-100 transition hover:bg-emerald-300/30">
                    <%= gettext("Open Command Bridge") %>
                  </.link>
                <% else %>
                  <.link navigate={~p"/users/register"} class="rounded-lg border border-cyan-300/50 bg-cyan-400/20 px-4 py-2 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/35">
                    <%= gettext("Start For Free") %>
                  </.link>
                  <.link navigate={~p"/users/log_in"} class="rounded-lg border border-gray-300/25 bg-gray-300/10 px-4 py-2 text-sm font-semibold text-gray-100 transition hover:bg-gray-200/20">
                    <%= gettext("I Already Have An Account") %>
                  </.link>
                <% end %>
              </div>
            </div>

            <aside class="rounded-2xl border border-cyan-500/25 bg-[#08182d]/85 p-5 shadow-[0_18px_70px_rgba(8,145,178,0.32)] backdrop-blur sm:p-6">
              <p class="text-[11px] font-semibold uppercase tracking-[0.26em] text-cyan-200/80"><%= gettext("Core Features") %></p>
              <ul class="mt-4 space-y-3 text-sm text-cyan-50/90">
                <li class="rounded-lg border border-cyan-500/20 bg-cyan-500/10 p-3"><%= gettext("Planetary economy with production chains and live resource pressure.") %></li>
                <li class="rounded-lg border border-cyan-500/20 bg-cyan-500/10 p-3"><%= gettext("Fleet management, planetary shipyards and strategic mobility lanes.") %></li>
                <li class="rounded-lg border border-cyan-500/20 bg-cyan-500/10 p-3"><%= gettext("Multi-universe progression with social diplomacy and conflict.") %></li>
              </ul>
            </aside>
          </div>
        </section>

        <section class="relative mx-auto max-w-6xl px-4 pb-14 sm:px-8 lg:px-12">
          <div class="grid gap-4 md:grid-cols-3">
            <article class="rounded-xl border border-cyan-500/20 bg-[#0a1a2f]/85 p-4">
              <p class="text-xs uppercase tracking-[0.16em] text-cyan-300/85"><%= gettext("Fair Game") %></p>
              <p class="mt-2 text-sm text-cyan-100/85"><%= gettext("Free-to-play design with no direct pay-to-win power sale.") %></p>
            </article>
            <article class="rounded-xl border border-emerald-500/20 bg-[#0a1d2a]/85 p-4">
              <p class="text-xs uppercase tracking-[0.16em] text-emerald-300/85"><%= gettext("Persistent Wars") %></p>
              <p class="mt-2 text-sm text-emerald-100/85"><%= gettext("Every decision affects your long-term position in your universe.") %></p>
            </article>
            <article class="rounded-xl border border-blue-500/20 bg-[#0a1628]/85 p-4">
              <p class="text-xs uppercase tracking-[0.16em] text-blue-300/85"><%= gettext("Live Strategy") %></p>
              <p class="mt-2 text-sm text-blue-100/85"><%= gettext("Build, defend and react quickly to player-driven events.") %></p>
            </article>
          </div>
        </section>
      </main>

      <footer class="border-t border-cyan-900/40 bg-[#031020]/90 px-4 py-3 text-center text-[11px] text-cyan-200/70">
        <%= gettext("Nexus: Downfall - The universe is dangerous, your timing must be perfect.") %>
      </footer>
    </div>
    """
  end
end
