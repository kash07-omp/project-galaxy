defmodule NexusDownfallWeb.UserRegistrationLive do
  @moduledoc "Registration LiveView — creates a new global account."

  use NexusDownfallWeb, :live_view

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div class="w-full max-w-md space-y-8">
        <div class="text-center">
          <h1 class="text-3xl font-bold text-cyan-400 tracking-widest uppercase">
            Create Account
          </h1>
          <p class="mt-2 text-gray-400 text-sm">Join the Nexus Downfall network</p>
        </div>

        <.form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-6"
        >
          <div>
            <.label for="user_email">Email</.label>
            <.input
              field={@form[:email]}
              type="email"
              id="user_email"
              autocomplete="email"
              required
            />
          </div>

          <div>
            <.label for="user_password">Password</.label>
            <.input
              field={@form[:password]}
              type="password"
              id="user_password"
              autocomplete="new-password"
              required
            />
            <p class="mt-1 text-xs text-gray-500">Minimum 12 characters</p>
          </div>

          <.button type="submit" class="w-full" phx-disable-with="Creating account…">
            Create Account
          </.button>
        </.form>

        <p class="text-center text-sm text-gray-500">
          Already have an account?
          <.link navigate={~p"/users/log_in"} class="text-cyan-400 hover:text-cyan-300 underline">
            Sign in
          </.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    socket = assign(socket, form: to_form(changeset, as: "user"), trigger_submit: false)
    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created! Welcome, #{user.email}")
         |> redirect(to: ~p"/users/log_in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end
end
