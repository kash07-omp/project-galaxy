defmodule NexusDownfallWeb.UserSettingsLive do
  @moduledoc "User account settings page — language / locale preference."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Accounts

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:current_locale, user.locale || "en")
     |> assign(:page_title, gettext("Account Settings"))}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 font-sans text-white">

      <!-- Top nav -->
      <nav class="flex items-center gap-3 bg-gray-900/95 border-b border-gray-800 px-4 h-10 shrink-0">
        <.link navigate={~p"/dashboard"} class="flex items-center gap-1.5 shrink-0">
          <span class="text-cyan-400 text-base">⬡</span>
          <span class="text-white font-bold tracking-widest text-xs uppercase">Nexus</span>
          <span class="text-cyan-400 font-bold text-xs">:</span>
          <span class="text-cyan-300 font-bold tracking-widest text-xs uppercase">Downfall</span>
        </.link>
        <span class="text-gray-600 text-xs">›</span>
        <span class="text-gray-400 text-xs">{gettext("Account Settings")}</span>
      </nav>

      <div class="max-w-xl mx-auto pt-12 px-4 pb-16">
        <h1 class="text-2xl font-bold text-white mb-8">{gettext("Account Settings")}</h1>

        <!-- Flash messages -->
        <%= if Phoenix.Flash.get(@flash, :info) do %>
          <div class="mb-4 px-4 py-3 rounded-lg bg-emerald-900/50 border border-emerald-700 text-emerald-300 text-sm">
            {Phoenix.Flash.get(@flash, :info)}
          </div>
        <% end %>
        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="mb-4 px-4 py-3 rounded-lg bg-red-900/50 border border-red-700 text-red-300 text-sm">
            {Phoenix.Flash.get(@flash, :error)}
          </div>
        <% end %>

        <!-- Language section -->
        <div class="bg-gray-900 rounded-2xl border border-gray-800 p-6 mb-6">
          <h2 class="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-4">
            {gettext("Language")}
          </h2>
          <form phx-submit="save_locale">
            <div class="flex gap-6 mb-6">
              <label class="flex items-center gap-3 cursor-pointer group">
                <input
                  type="radio"
                  name="locale"
                  value="en"
                  checked={@current_locale == "en"}
                  class="accent-cyan-500 w-4 h-4"
                />
                <span class="text-sm text-gray-300 group-hover:text-white">🇬🇧 English</span>
              </label>
              <label class="flex items-center gap-3 cursor-pointer group">
                <input
                  type="radio"
                  name="locale"
                  value="es"
                  checked={@current_locale == "es"}
                  class="accent-cyan-500 w-4 h-4"
                />
                <span class="text-sm text-gray-300 group-hover:text-white">🇪🇸 Español</span>
              </label>
              <label class="flex items-center gap-3 cursor-pointer group">
                <input
                  type="radio"
                  name="locale"
                  value="fr"
                  checked={@current_locale == "fr"}
                  class="accent-cyan-500 w-4 h-4"
                />
                <span class="text-sm text-gray-300 group-hover:text-white">🇫🇷 Français</span>
              </label>
            </div>
            <button
              type="submit"
              class="px-5 py-2 bg-cyan-700 hover:bg-cyan-600 text-white rounded-lg text-sm font-semibold transition"
            >
              {gettext("Save")}
            </button>
          </form>
        </div>

        <!-- Account info -->
        <div class="bg-gray-900 rounded-2xl border border-gray-800 p-6 mb-8">
          <h2 class="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-3">{gettext("Account")}</h2>
          <p class="text-sm text-gray-300">{@current_user.email}</p>
        </div>

        <.link navigate={~p"/dashboard"} class="text-gray-500 hover:text-gray-300 text-sm transition">
          ← {gettext("Back to map")}
        </.link>
      </div>
    </div>
    """
  end

  def handle_event("save_locale", %{"locale" => locale}, socket) when locale in ["es", "en", "fr"] do
    user = socket.assigns.current_user

    case Accounts.update_user_locale(user, locale) do
      {:ok, updated_user} ->
        Gettext.put_locale(NexusDownfallWeb.Gettext, locale)

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:current_locale, locale)
         |> put_flash(:info, gettext("Language updated successfully."))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Error saving language."))}
    end
  end

  def handle_event("save_locale", _params, socket) do
    {:noreply, put_flash(socket, :error, gettext("Invalid language."))}
  end
end
