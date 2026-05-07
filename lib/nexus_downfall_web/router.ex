defmodule NexusDownfallWeb.Router do
  @moduledoc false

  use NexusDownfallWeb, :router

  import NexusDownfallWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NexusDownfallWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ---------------------------------------------------------------------------
  # Public browser routes (no authentication required)
  # ---------------------------------------------------------------------------
  scope "/", NexusDownfallWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    live_session :redirect_if_authenticated,
      on_mount: [{NexusDownfallWeb.UserAuth, :redirect_if_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", NexusDownfallWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    delete "/users/log_out", UserSessionController, :delete
  end

  # ---------------------------------------------------------------------------
  # Authenticated routes
  # ---------------------------------------------------------------------------
  scope "/", NexusDownfallWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{NexusDownfallWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index
      live "/universes", UniverseListLive, :index
      live "/universes/:slug/join", UniverseJoinLive, :new
      live "/planets/:id", PlanetLive, :show
      live "/users/settings", UserSettingsLive, :edit
    end
  end

  # ---------------------------------------------------------------------------
  # Dev tools — LiveDashboard (dev only)
  # ---------------------------------------------------------------------------
  if Application.compile_env(:nexus_downfall, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NexusDownfallWeb.Telemetry
    end
  end
end
