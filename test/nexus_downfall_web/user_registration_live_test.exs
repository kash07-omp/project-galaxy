defmodule NexusDownfallWeb.UserRegistrationLiveTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /users/register" do
    test "renders registration form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")
      assert html =~ "Create Account"
      assert html =~ "Account name"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "redirects authenticated users to dashboard", %{conn: conn} do
      {:ok, user} =
        NexusDownfall.Accounts.register_user(%{
          account_name: "Taken#{System.unique_integer()}",
          email: "taken#{System.unique_integer()}@example.com",
          password: "correcthorse42!"
        })

      token = NexusDownfall.Accounts.generate_user_session_token(user)
      conn = conn |> Phoenix.ConnTest.init_test_session(%{"_nexus_downfall_user_token" => token})

      assert {:error, {:redirect, %{to: "/universes"}}} = live(conn, ~p"/users/register")
    end
  end

  describe "Registration form submit" do
    test "creates account and redirects to universe selection", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      suffix = System.unique_integer([:positive])

      form =
        form(lv, "#registration_form",
          user: %{
            account_name: "Cmd#{suffix}",
            email: "new#{suffix}@example.com",
            password: "supersecure123!"
          }
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == "/universes"
    end

    test "shows validation errors on invalid data" do
      {:ok, lv, _html} = live(build_conn(), ~p"/users/register")

      html =
        lv
        |> form("#registration_form", user: %{account_name: "x", email: "bad", password: "short"})
        |> render_change()

      assert html =~ "must have the @ sign"
    end
  end
end
