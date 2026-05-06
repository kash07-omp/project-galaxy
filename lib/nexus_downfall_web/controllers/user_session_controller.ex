defmodule NexusDownfallWeb.UserSessionController do
  @moduledoc "Handles login and logout via POST/DELETE."

  use NexusDownfallWeb, :controller

  alias NexusDownfall.Accounts
  alias NexusDownfallWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/users/log_in")

      user ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user, user_params)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
