defmodule NexusDownfallWeb.ConnCase do
  @moduledoc """
  ExUnit case template for controller/LiveView tests that need an HTTP connection.

  Sets up a sandbox DB transaction per test (same isolation as DataCase)
  and provides a `conn` fixture with a built Phoenix conn.

  Usage:
      use NexusDownfallWeb.ConnCase, async: true
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use NexusDownfallWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import NexusDownfallWeb.ConnCase

      @endpoint NexusDownfallWeb.Endpoint
    end
  end

  setup tags do
    NexusDownfall.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
