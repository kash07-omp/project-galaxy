defmodule NexusDownfallWeb.UserRegistrationController do
  @moduledoc "Handles account registration and immediate sign-in."

  use NexusDownfallWeb, :controller

  alias NexusDownfall.Accounts
  alias NexusDownfallWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Account created! Welcome, #{user.account_name}")
        |> UserAuth.log_in_user(user, user_params)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not create account. Review your data and try again.")
        |> redirect(to: ~p"/users/register")
    end
  end
end
