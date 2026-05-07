defmodule NexusDownfallWeb.UniverseJoinLive do
  @moduledoc """
  LiveView for joining a universe.

  On submit, creates a `UniverseUser` and an initial `Planet` for the player.
  """

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.UniverseUser
  alias NexusDownfall.Planets
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe

  on_mount {NexusDownfallWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 p-6 flex items-center justify-center">
      <div class="w-full max-w-md space-y-8">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-cyan-400 tracking-widest uppercase">Join Universe</h1>

          <p class="mt-2 text-gray-400 text-sm">{@universe.name}</p>
        </div>

        <.form
          for={@form}
          id="join_universe_form"
          phx-submit="join"
          phx-change="validate"
          class="space-y-6"
        >
          <div>
            <.label for="universe_user_username">Commander name in this universe</.label>

            <.input
              field={@form[:username]}
              type="text"
              id="universe_user_username"
              placeholder="Darth Kharnak"
              required
            />
            <p class="mt-1 text-xs text-gray-500">3–24 characters. Visible to other players.</p>
          </div>

          <div>
            <.label for="planet_name">Name your home planet</.label>

            <.input
              field={@form[:planet_name]}
              type="text"
              id="planet_name"
              name="join[planet_name]"
              placeholder="Terra Nova"
              value={@planet_name}
              required
            />
          </div>

          <.button type="submit" class="w-full" phx-disable-with="Joining…">
            Claim your territory
          </.button>
        </.form>

        <div class="text-center">
          <.link navigate={~p"/universes"} class="text-gray-500 hover:text-gray-300 text-sm underline">
            ← Back to universe list
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"slug" => slug}, _session, socket) do
    universe = Universe.get_universe_by_slug(slug)

    case universe do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Universe not found.")
         |> redirect(to: ~p"/universes")}

      %{status: "open"} = universe ->
        changeset = Accounts.change_join_universe(%UniverseUser{})

        {:ok,
         assign(socket,
           universe: universe,
           form: to_form(changeset, as: "universe_user"),
           planet_name: ""
         )}

      _universe ->
        {:ok,
         socket
         |> put_flash(:error, "This universe is no longer accepting players.")
         |> redirect(to: ~p"/universes")}
    end
  end

  def handle_event("validate", %{"universe_user" => params}, socket) do
    changeset = Accounts.change_join_universe(%UniverseUser{}, params)
    {:noreply, assign(socket, form: to_form(changeset, as: "universe_user"))}
  end

  def handle_event(
        "join",
        %{"universe_user" => uu_params, "join" => %{"planet_name" => planet_name}},
        socket
      ) do
    %{current_user: user, universe: universe} = socket.assigns

    solar_system_id = NexusDownfall.Universe.find_available_solar_system(universe)

    if is_nil(solar_system_id) do
      {:noreply, put_flash(socket, :error, "No available star systems in this universe yet.")}
    else
      with {:ok, {universe_user, _planet}} <-
             Repo.transaction(fn ->
               with {:ok, universe_user} <- Accounts.join_universe(user, universe, uu_params),
                    {:ok, planet} <-
                      Planets.claim_planet_slot(solar_system_id, universe_user.id, planet_name) do
                 {universe_user, planet}
               else
                 {:error, reason} -> Repo.rollback(reason)
               end
             end) do
        {:noreply,
         socket
         |> put_flash(:info, "Welcome to #{universe.name}, #{universe_user.username}!")
         |> redirect(to: ~p"/dashboard")}
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset, as: "universe_user"))}

        {:error, :no_available_slots} ->
          {:noreply, put_flash(socket, :error, "No available planet slots in this universe yet.")}
      end
    end
  end
end
