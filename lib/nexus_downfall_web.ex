defmodule NexusDownfallWeb do
  @moduledoc """
  Entry point for the web layer of Nexus: Downfall.

  Provides `use NexusDownfallWeb, :module_type` macros that inject
  the correct Phoenix boilerplate for each type of module.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: NexusDownfallWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: NexusDownfallWeb.Gettext
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {NexusDownfallWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import NexusDownfallWeb.CoreComponents
      import NexusDownfallWeb.GameComponents
      import NexusDownfallWeb.UnitDetailModal
      use Gettext, backend: NexusDownfallWeb.Gettext

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: NexusDownfallWeb.Endpoint,
        router: NexusDownfallWeb.Router,
        statics: NexusDownfallWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
