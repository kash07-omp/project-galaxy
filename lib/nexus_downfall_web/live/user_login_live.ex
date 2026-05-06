defmodule NexusDownfallWeb.UserLoginLive do
  @moduledoc "Login LiveView — authenticates an existing account."

  use NexusDownfallWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div class="w-full max-w-md space-y-8">
        <div class="text-center">
          <h1 class="text-3xl font-bold text-cyan-400 tracking-widest uppercase">
            Sign In
          </h1>
          <p class="mt-2 text-gray-400 text-sm">Access the command bridge</p>
        </div>

        <.form
          for={@form}
          id="login_form"
          action={~p"/users/log_in"}
          phx-update="ignore"
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
              autocomplete="current-password"
              required
            />
          </div>

          <.button type="submit" class="w-full" phx-disable-with="Signing in…">
            Sign In
          </.button>
        </.form>

        <p class="text-center text-sm text-gray-500">
          No account yet?
          <.link navigate={~p"/users/register"} class="text-cyan-400 hover:text-cyan-300 underline">
            Create one
          </.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(%{}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
