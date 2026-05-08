defmodule NexusDownfallWeb.UserAuth do
  @moduledoc """
  Authentication plug and helpers for the web layer.

  Provides:
  - `fetch_current_user/2` — reads session token and assigns `current_user`.
  - `require_authenticated_user/2` — redirects unauthenticated requests.
  - `redirect_if_authenticated/2` — redirects already-authenticated requests.
  - `log_in_user/3` — writes session token and redirects.
  - `log_out_user/1` — deletes token and redirects to home.
  """

  use NexusDownfallWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias NexusDownfall.Accounts

  # Session key that stores the raw token.
  @session_key "_nexus_downfall_user_token"
  # Cookie returned-to path key.
  @return_to_key "_nexus_downfall_return_to"

  # ---------------------------------------------------------------------------
  # Plug callbacks
  # ---------------------------------------------------------------------------

  @doc "Fetches the current user from the session and assigns it."
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    current_user =
      if user_token, do: Accounts.get_user_by_session_token(user_token)

    assign(conn, :current_user, current_user)
  end

  @doc "Redirects to login if the user is not authenticated."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  @doc "Redirects to dashboard if the user is already authenticated."
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/universes")
      |> halt()
    else
      conn
    end
  end

  # ---------------------------------------------------------------------------
  # Login / logout helpers (called from LiveView on_mount or controllers)
  # ---------------------------------------------------------------------------

  @doc "Logs in the user by writing a session token and redirecting."
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)

    return_to = get_session(conn, @return_to_key)

    conn
    |> renew_session()
    |> put_session(@session_key, token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: return_to || ~p"/universes")
  end

  @doc "Logs out the user by deleting the token and redirecting to home."
  def log_out_user(conn) do
    user_token = get_session(conn, @session_key)
    user_token && Accounts.delete_user_session_token(user_token)

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  # ---------------------------------------------------------------------------
  # LiveView on_mount helpers
  # ---------------------------------------------------------------------------

  @doc """
  LiveView `on_mount` callback variants:

  - `:mount_current_user` — assigns current_user (optional, no redirect).
  - `:ensure_authenticated` — assigns current_user, redirects to login if nil.
  - `:ensure_joined_universe` — redirects to universes list if user has no membership.
  - `:redirect_if_authenticated` — redirects to dashboard if user is logged in.
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      Gettext.put_locale(NexusDownfallWeb.Gettext, socket.assigns.current_user.locale || "en")
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/universes")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:ensure_joined_universe, _params, session, socket) do
    socket = mount_current_user(session, socket)

    case socket.assigns.current_user do
      nil ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

        {:halt, socket}

      user ->
        if Accounts.has_universe_memberships?(user.id) do
          {:cont, socket}
        else
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :info,
              "Join a universe first to access command, fleet and galaxy screens."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/universes")

          {:halt, socket}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session[@session_key] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, @session_key) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [])
      {nil, conn}
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, @return_to_key, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_write_remember_me_cookie(conn, _token, %{"remember_me" => "true"}) do
    # Future: write a long-lived signed cookie. Placeholder for Phase 2.
    conn
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params), do: conn
end
