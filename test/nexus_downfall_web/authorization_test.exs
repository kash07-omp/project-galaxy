defmodule NexusDownfallWeb.AuthorizationTest do
  @moduledoc "Verifies unauthenticated requests are redirected to login."

  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @protected_routes [~p"/dashboard", ~p"/universes"]

  describe "unauthenticated access" do
    for route <- @protected_routes do
      test "redirects #{route} to login", %{conn: conn} do
        result = live(conn, unquote(route))
        assert {:error, {:redirect, %{to: "/users/log_in"}}} = result
      end
    end
  end
end
