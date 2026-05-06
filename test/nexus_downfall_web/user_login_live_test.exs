defmodule NexusDownfallWeb.UserLoginLiveTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    {:ok, user} =
      NexusDownfall.Accounts.register_user(%{
        email: "login#{System.unique_integer()}@example.com",
        password: "correcthorsebatt!"
      })

    %{user: user}
  end

  describe "GET /users/log_in" do
    test "renders login form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")
      assert html =~ "Sign In"
    end

    test "redirects authenticated users to dashboard", %{conn: conn, user: user} do
      token = NexusDownfall.Accounts.generate_user_session_token(user)
      conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/users/log_in")
    end
  end

  describe "POST /users/log_in (via form submit)" do
    test "logs in and redirects to dashboard", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => "correcthorsebatt!"}
        })

      assert redirected_to(conn) == ~p"/dashboard"
    end

    test "shows flash error for wrong password", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => "wrong-password-!"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      conn = get(recycle(conn), ~p"/users/log_in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs out and redirects to home", %{conn: conn, user: user} do
      token = NexusDownfall.Accounts.generate_user_session_token(user)
      conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
