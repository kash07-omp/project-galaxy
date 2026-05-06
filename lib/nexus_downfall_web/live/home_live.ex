defmodule NexusDownfallWeb.HomeLive do
  @moduledoc """
  Home page LiveView — Phase 0 splash screen.

  Replaced in Phase 1 with the dashboard after authentication.
  """

  use NexusDownfallWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Nexus: Downfall")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 flex flex-col items-center justify-center gap-8 p-8">
      <div class="text-center space-y-4">
        <p class="text-cyan-500 tracking-[0.4em] text-xs font-semibold uppercase">
          MMORTS · Browser-based
        </p>
        <h1 class="text-6xl font-black tracking-tight text-white drop-shadow-[0_0_24px_rgba(6,182,212,0.5)]">
          NEXUS: DOWNFALL
        </h1>
        <p class="text-gray-400 text-lg max-w-xl mx-auto">
          Colonize. Expand. Dominate. Build your galactic empire from a single planet
          and forge alliances — or crush your enemies.
        </p>
      </div>

      <div class="flex flex-col items-center gap-3 text-sm text-gray-500 border border-gray-800 rounded-xl px-8 py-6">
        <p class="text-gray-300 font-semibold">Foundation — Phase 0</p>
        <p>Project scaffolded. Backend services starting up.</p>
        <p class="text-cyan-600">Authentication and galaxy generation coming in Phase 1.</p>
      </div>
    </div>
    """
  end
end
