defmodule NexusDownfallWeb.UniverseJoinLive do
  @moduledoc """
  LiveView for joining a universe.

  On submit, creates a `UniverseUser` and an initial `Planet` for the player.
  """

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Accounts
  alias NexusDownfall.Planets
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe

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

      <main class="relative min-h-[calc(100vh-2.5rem)] px-4 py-8 sm:px-8 lg:px-12">
        <div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_10%_15%,rgba(34,211,238,0.22),transparent_30%),radial-gradient(circle_at_85%_15%,rgba(45,212,191,0.16),transparent_35%),radial-gradient(circle_at_40%_92%,rgba(59,130,246,0.18),transparent_32%)]" />

        <div class="relative mx-auto max-w-6xl space-y-6">
          <section class="rounded-2xl border border-cyan-500/20 bg-[#091427]/90 p-6 shadow-[0_24px_70px_rgba(14,116,144,0.25)] backdrop-blur">
            <p class="text-[11px] uppercase tracking-[0.34em] text-cyan-300/80">
              {gettext("Universe Join Wizard")}
            </p>
            <h1 class="mt-2 text-3xl font-black uppercase tracking-[0.08em] text-cyan-100 sm:text-4xl">
              {@universe.name}
            </h1>
            <p class="mt-3 max-w-3xl text-sm text-cyan-100/80 sm:text-base">
              {gettext(
                "Configure your first deployment in two steps: choose a species and select your starting galaxy."
              )}
            </p>

            <div class="mt-4 flex items-center gap-2 text-xs">
              <span class={step_badge_class(@step == :species)}>{gettext("1. Species")}</span>
              <span class={step_badge_class(@step == :galaxy)}>{gettext("2. Galaxy")}</span>
            </div>
          </section>

          <section :if={@step == :species} class="space-y-4">
            <h2 class="text-lg font-bold text-white">{gettext("Choose your species")}</h2>

            <div class="grid gap-5 md:grid-cols-3">
              <%= for species <- species_cards() do %>
                <button
                  type="button"
                  phx-click="choose_species"
                  phx-value-species={species.id}
                  class="group overflow-hidden rounded-2xl border border-cyan-500/20 bg-[#081126] text-left transition hover:border-cyan-300/50 hover:shadow-[0_20px_45px_rgba(8,145,178,0.28)]"
                >
                  <div class="h-28 bg-[url('/images/space_background_2.jpg')] bg-cover bg-center">
                    <div class={"h-full w-full #{species.overlay_class}"} />
                  </div>
                  <div class="space-y-3 p-4">
                    <h3 class="text-base font-bold text-cyan-100">{species.name}</h3>
                    <p class="text-sm text-gray-300">{species.description}</p>
                    <p class="rounded-lg border border-cyan-500/25 bg-cyan-500/10 px-3 py-2 text-xs font-semibold text-cyan-100">
                      {species.bonus}
                    </p>
                  </div>
                </button>
              <% end %>
            </div>
          </section>

          <section :if={@step == :galaxy} class="space-y-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <h2 class="text-lg font-bold text-white">{gettext("Select your starting galaxy")}</h2>
              <button
                type="button"
                phx-click="back_to_species"
                class="rounded-lg border border-gray-700 bg-gray-900 px-3 py-1.5 text-xs font-semibold text-gray-300 transition hover:border-cyan-500 hover:text-cyan-200"
              >
                {gettext("Change species")}
              </button>
            </div>

            <div class="rounded-xl border border-cyan-500/20 bg-cyan-500/10 px-4 py-3 text-sm text-cyan-100">
              <span class="font-semibold">{gettext("Selected species")}:</span>
              {selected_species_name(@selected_species)}
            </div>

            <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              <%= for galaxy <- @galaxy_stats do %>
                <button
                  type="button"
                  phx-click="select_galaxy"
                  phx-value-galaxy_id={galaxy.galaxy_id}
                  class={galaxy_card_class(galaxy.galaxy_id == @selected_galaxy_id)}
                >
                  <div class="flex items-center justify-between">
                    <h3 class="text-base font-bold text-white">
                      {gettext("Galaxy %{number}", number: galaxy.number)}
                    </h3>
                    <span
                      :if={galaxy.galaxy_id == @recommended_galaxy_id}
                      class="rounded-full border border-emerald-400/50 bg-emerald-500/20 px-2 py-1 text-[10px] font-bold uppercase tracking-wide text-emerald-100"
                    >
                      {gettext("Recommended")}
                    </span>
                  </div>

                  <div class="mt-3 grid grid-cols-3 gap-2 text-xs">
                    <div class="rounded-md border border-orange-400/20 bg-orange-500/10 px-2 py-2">
                      <p class="uppercase tracking-wide text-orange-100/75">{gettext("Players")}</p>
                      <p class="mt-1 text-sm font-bold text-orange-100">{galaxy.users_count}</p>
                    </div>
                    <div class="rounded-md border border-cyan-400/20 bg-cyan-500/10 px-2 py-2">
                      <p class="uppercase tracking-wide text-cyan-100/75">{gettext("Occupied")}</p>
                      <p class="mt-1 text-sm font-bold text-cyan-100">{galaxy.occupied_planets}</p>
                    </div>
                    <div class="rounded-md border border-emerald-400/20 bg-emerald-500/10 px-2 py-2">
                      <p class="uppercase tracking-wide text-emerald-100/75">{gettext("Free")}</p>
                      <p class="mt-1 text-sm font-bold text-emerald-100">{galaxy.free_planets}</p>
                    </div>
                  </div>
                </button>
              <% end %>
            </div>

            <div class="pt-2">
              <button
                type="button"
                phx-click="join"
                disabled={is_nil(@selected_galaxy_id) or is_nil(@selected_species)}
                class="inline-flex items-center rounded-lg border border-cyan-400/40 bg-cyan-500/30 px-5 py-2.5 text-sm font-bold text-cyan-50 transition hover:bg-cyan-400/40 disabled:cursor-not-allowed disabled:border-gray-600 disabled:bg-gray-800 disabled:text-gray-500"
              >
                {gettext("Confirm deployment")}
              </button>
            </div>
          </section>

          <div class="text-sm text-gray-400">
            <.link navigate={~p"/universes"} class="underline hover:text-gray-200">
              {gettext("Back to universe selection")}
            </.link>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def mount(%{"slug" => slug}, _session, socket) do
    universe = Universe.get_universe_by_slug(slug)

    case universe do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Universe not found."))
         |> redirect(to: ~p"/universes")}

      %{status: "open"} = universe ->
        if Accounts.get_universe_user(socket.assigns.current_user.id, universe.id) do
          {:ok,
           socket
           |> put_flash(:info, gettext("You already joined this universe."))
           |> redirect(to: ~p"/dashboard")}
        else
          galaxy_stats = Universe.list_galaxy_join_stats(universe)
          recommended_galaxy_id = Universe.recommended_galaxy_id(universe)

          {:ok,
           assign(socket,
             universe: universe,
             step: :species,
             selected_species: nil,
             selected_galaxy_id: recommended_galaxy_id,
             galaxy_stats: galaxy_stats,
             recommended_galaxy_id: recommended_galaxy_id,
             show_user_menu: false
           )}
        end

      _universe ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This universe is no longer accepting players."))
         |> redirect(to: ~p"/universes")}
    end
  end

  def handle_event("choose_species", %{"species" => species}, socket),
    do: {:noreply, assign(socket, step: :galaxy, selected_species: species)}

  def handle_event("back_to_species", _, socket), do: {:noreply, assign(socket, step: :species)}

  def handle_event("select_galaxy", %{"galaxy_id" => galaxy_id}, socket),
    do: {:noreply, assign(socket, selected_galaxy_id: String.to_integer(galaxy_id))}

  def handle_event("toggle_user_menu", _, socket),
    do: {:noreply, update(socket, :show_user_menu, &(!&1))}

  def handle_event("join", _params, socket) do
    %{current_user: user, universe: universe} = socket.assigns
    selected_species = socket.assigns.selected_species
    selected_galaxy_id = socket.assigns.selected_galaxy_id

    if is_nil(selected_species) or is_nil(selected_galaxy_id) do
      {:noreply,
       put_flash(socket, :error, gettext("Select species and galaxy before confirming."))}
    else
      solar_system_id =
        NexusDownfall.Universe.find_available_solar_system_in_galaxy(universe, selected_galaxy_id)

      if is_nil(solar_system_id) do
        {:noreply,
         put_flash(socket, :error, gettext("No available planet slots in this galaxy."))}
      else
        uu_params = %{
          "username" => user.account_name,
          "species" => selected_species
        }

        with {:ok, {universe_user, _planet}} <-
               Repo.transaction(fn ->
                 with {:ok, universe_user} <- Accounts.join_universe(user, universe, uu_params),
                      {:ok, planet} <-
                        Planets.claim_planet_slot_in_galaxy(
                          selected_galaxy_id,
                          universe_user.id,
                          default_planet_name(user.account_name)
                        ) do
                   {universe_user, planet}
                 else
                   {:error, reason} -> Repo.rollback(reason)
                 end
               end) do
          {:noreply,
           socket
           |> put_flash(
             :info,
             gettext("Welcome to %{universe}, %{commander}!",
               universe: universe.name,
               commander: universe_user.username
             )
           )
           |> redirect(to: ~p"/dashboard")}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, first_error_message(changeset))}

          {:error, :no_available_slots} ->
            {:noreply,
             put_flash(socket, :error, gettext("No available planet slots in this galaxy."))}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, gettext("Could not complete deployment."))}
        end
      end
    end
  end

  defp default_planet_name(account_name) when is_binary(account_name), do: "#{account_name} Prime"
  defp default_planet_name(_), do: "Nova Prime"

  defp selected_species_name(nil), do: "-"

  defp selected_species_name(id) do
    species_cards()
    |> Enum.find(fn s -> s.id == id end)
    |> case do
      nil -> id
      species -> species.name
    end
  end

  defp species_cards do
    [
      %{
        id: "human",
        name: gettext("Human"),
        description:
          gettext("Balanced strategists with explosive demographic growth in early colonies."),
        bonus: gettext("Fast reproduction: +5% population generation speed."),
        overlay_class: "bg-gradient-to-br from-cyan-900/65 via-cyan-600/35 to-transparent"
      },
      %{
        id: "reptilian",
        name: gettext("Reptilian"),
        description:
          gettext("Predatory warlords with hardened combat doctrine and relentless pressure."),
        bonus: gettext("Brute force: +5% attack power on all ships."),
        overlay_class: "bg-gradient-to-br from-emerald-900/70 via-emerald-600/35 to-transparent"
      },
      %{
        id: "avianoid",
        name: gettext("Avianoid"),
        description: gettext("High-altitude thinkers focused on rapid scientific breakthroughs."),
        bonus: gettext("Advanced intellect: +5% research speed."),
        overlay_class: "bg-gradient-to-br from-indigo-900/70 via-indigo-600/35 to-transparent"
      }
    ]
  end

  defp step_badge_class(active?) do
    if active? do
      "rounded-full border border-cyan-300/60 bg-cyan-500/25 px-3 py-1 font-semibold text-cyan-50"
    else
      "rounded-full border border-gray-700 bg-gray-900 px-3 py-1 font-semibold text-gray-400"
    end
  end

  defp galaxy_card_class(selected?) do
    base =
      "rounded-xl border bg-[#081126] p-4 text-left transition hover:border-cyan-400/45 hover:shadow-[0_16px_32px_rgba(8,145,178,0.23)]"

    if selected? do
      base <> " border-cyan-300/70 shadow-[0_0_0_1px_rgba(34,211,238,0.45)_inset]"
    else
      base <> " border-cyan-500/20"
    end
  end

  defp first_error_message(%Ecto.Changeset{errors: [{_field, {message, _meta}} | _]}), do: message
  defp first_error_message(_), do: gettext("Could not complete deployment.")
end
