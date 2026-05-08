defmodule NexusDownfallWeb.AuthorizationTest do
  @moduledoc "Verifies unauthenticated requests are redirected to login."

  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias NexusDownfall.Accounts

  @protected_routes [
    "/dashboard",
    "/universes",
    "/fleet",
    "/planets",
    "/galaxies/1",
    "/systems/1"
  ]

  describe "unauthenticated access" do
    for route <- @protected_routes do
      test "redirects #{route} to login", %{conn: conn} do
        result = live(conn, unquote(route))
        assert {:error, {:redirect, %{to: "/users/log_in"}}} = result
      end
    end
  end

  describe "authenticated but not joined" do
    test "redirects dashboard and game routes to universe list", %{conn: conn} do
      {:ok, user} =
        Accounts.register_user(%{
          account_name: "Guard#{System.unique_integer([:positive])}",
          email: "guard-#{System.unique_integer([:positive])}@example.com",
          password: "supersecure123!"
        })

      token = Accounts.generate_user_session_token(user)
      conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

      assert {:error, {:redirect, %{to: "/universes"}}} = live(conn, "/dashboard")
      assert {:error, {:redirect, %{to: "/universes"}}} = live(conn, "/fleet")
    end
  end
end
