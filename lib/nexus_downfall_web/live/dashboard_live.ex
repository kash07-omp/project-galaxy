defmodule NexusDownfallWeb.DashboardLive do
  @moduledoc "Authenticated dashboard — shows the player's active universes."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Accounts

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 p-6">
      <header class="flex items-center justify-between mb-8">
        <h1 class="text-2xl font-bold text-cyan-400 tracking-widest uppercase">
          Command Bridge
        </h1>
        <div class="flex items-center gap-4 text-sm text-gray-400">
          <span>{@current_user.email}</span>
          <.link
            href={~p"/users/log_out"}
            method="delete"
            class="text-red-400 hover:text-red-300 underline"
          >
            Log out
          </.link>
        </div>
      </header>

      <section>
        <h2 class="text-lg font-semibold text-gray-300 mb-4">Your Universes</h2>

        <%= if @memberships == [] do %>
          <div class="rounded-lg border border-gray-800 bg-gray-900 p-8 text-center">
            <p class="text-gray-500 mb-4">You have not joined any universe yet.</p>
            <.link
              navigate={~p"/universes"}
              class="inline-block px-4 py-2 rounded bg-cyan-700 hover:bg-cyan-600 text-white text-sm font-medium"
            >
              Browse Universes
            </.link>
          </div>
        <% else %>
          <ul class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for uu <- @memberships do %>
              <li class="rounded-lg border border-gray-800 bg-gray-900 p-4 space-y-1">
                <p class="text-cyan-300 font-semibold">{uu.universe.name}</p>
                <p class="text-xs text-gray-500">
                  alias: <span class="text-gray-300">{uu.username}</span>
                </p>
                <p class="text-xs text-gray-500">
                  score: <span class="text-gray-300">{uu.score}</span>
                </p>
              </li>
            <% end %>
          </ul>
        <% end %>
      </section>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    memberships = Accounts.list_universe_memberships(socket.assigns.current_user.id)
    {:ok, assign(socket, memberships: memberships)}
  end
end
