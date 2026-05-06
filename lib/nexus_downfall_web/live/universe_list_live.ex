defmodule NexusDownfallWeb.UniverseListLive do
  @moduledoc "Lists open universes the player can join."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Universe

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 p-6">
      <h1 class="text-2xl font-bold text-cyan-400 tracking-widest uppercase mb-6">
        Open Universes
      </h1>

      <%= if @universes == [] do %>
        <p class="text-gray-500">No universes are currently open for registration.</p>
      <% else %>
        <ul class="space-y-4">
          <%= for universe <- @universes do %>
            <li class="rounded-lg border border-gray-800 bg-gray-900 p-5 flex items-center justify-between">
              <div>
                <p class="text-cyan-300 font-semibold">{universe.name}</p>
                <p class="text-xs text-gray-500 mt-1">slug: {universe.slug}</p>
              </div>
              <.link
                navigate={~p"/universes/#{universe.slug}/join"}
                class="px-3 py-1 rounded bg-cyan-700 hover:bg-cyan-600 text-sm text-white font-medium"
              >
                Join
              </.link>
            </li>
          <% end %>
        </ul>
      <% end %>

      <div class="mt-6">
        <.link navigate={~p"/dashboard"} class="text-gray-500 hover:text-gray-300 text-sm underline">
          ← Back to Dashboard
        </.link>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    universes = Universe.list_open_universes()
    {:ok, assign(socket, universes: universes)}
  end
end
