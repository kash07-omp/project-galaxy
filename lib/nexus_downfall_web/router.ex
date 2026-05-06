defmodule NexusDownfallWeb.Router do
  @moduledoc false

  use NexusDownfallWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NexusDownfallWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ---------------------------------------------------------------------------
  # Public browser routes
  # ---------------------------------------------------------------------------
  scope "/", NexusDownfallWeb do
    pipe_through :browser

    live "/", HomeLive, :index
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
