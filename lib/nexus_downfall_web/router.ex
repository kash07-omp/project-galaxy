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

    post "/users/register", UserRegistrationController, :create
    post "/users/log_in", UserSessionController, :create
  end

  scope "/", NexusDownfallWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    get "/404", ErrorPageController, :not_found
    delete "/users/log_out", UserSessionController, :delete
  end

  # ---------------------------------------------------------------------------
  # Authenticated routes
  # ---------------------------------------------------------------------------
  scope "/", NexusDownfallWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated_onboarding,
      on_mount: [
        {NexusDownfallWeb.UserAuth, :ensure_authenticated},
        {NexusDownfallWeb.NotificationHooks, :default}
      ] do
      live "/universes", UniverseListLive, :index
      live "/universes/:slug/join", UniverseJoinLive, :new
      live "/users/settings", UserSettingsLive, :edit
      live "/notifications", NotificationsLive, :index
      live "/notifications/:id", NotificationsLive, :show
    end

    live_session :require_universe_membership,
      on_mount: [
        {NexusDownfallWeb.UserAuth, :ensure_authenticated},
        {NexusDownfallWeb.UserAuth, :ensure_joined_universe},
        {NexusDownfallWeb.NotificationHooks, :default}
      ] do
      live "/dashboard", DashboardLive, :index
      live "/fleet", FleetLive, :index
      live "/planets/:id", PlanetLive, :show
      live "/planets", PlanetsListLive, :index
      live "/galaxies/:galaxy_id", GalaxyLive, :show
      live "/systems/:id", SolarSystemLive, :show
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

  scope "/", NexusDownfallWeb do
    pipe_through :browser

    get "/*path", ErrorPageController, :not_found
  end
end
