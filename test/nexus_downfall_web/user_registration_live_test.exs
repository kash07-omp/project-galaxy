defmodule NexusDownfallWeb.UserRegistrationLiveTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /users/register" do
    test "renders registration form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")
      assert html =~ "Create Account"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "redirects authenticated users to dashboard", %{conn: conn} do
      {:ok, user} =
        NexusDownfall.Accounts.register_user(%{
          email: "taken#{System.unique_integer()}@example.com",
          password: "correcthorse42!"
        })

      token = NexusDownfall.Accounts.generate_user_session_token(user)
      conn = conn |> Phoenix.ConnTest.init_test_session(%{"_nexus_downfall_user_token" => token})

      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/users/register")
    end
  end

  describe "Registration form submit" do
    test "creates account and redirects to login" do
      {:ok, lv, _html} = live(build_conn(), ~p"/users/register")

      result =
        lv
        |> form("#registration_form", user: %{email: "new@example.com", password: "supersecure123!"})
        |> render_submit()

      assert {:error, {:redirect, %{to: "/users/log_in"}}} = result
    end

    test "shows validation errors on invalid data" do
      {:ok, lv, _html} = live(build_conn(), ~p"/users/register")

      html =
        lv
        |> form("#registration_form", user: %{email: "bad", password: "short"})
        |> render_change()

      assert html =~ "must have the @ sign"
    end
  end
end
