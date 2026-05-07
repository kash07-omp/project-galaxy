defmodule NexusDownfall.AccountsTest do
  use NexusDownfall.DataCase, async: true

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.User

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        email: "user#{System.unique_integer()}@example.com",
        password: "superSecureP@ss1"
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # register_user/1
  # ---------------------------------------------------------------------------

  describe "register_user/1" do
    test "creates a user with valid attrs" do
      attrs = valid_user_attrs()
      assert {:ok, %User{} = user} = Accounts.register_user(attrs)
      assert user.email == String.downcase(attrs.email)
      refute user.hashed_password == nil
    end

    test "rejects duplicate email (case-insensitive)" do
      attrs = valid_user_attrs()
      {:ok, _} = Accounts.register_user(attrs)
      assert {:error, changeset} = Accounts.register_user(Map.update!(attrs, :email, &String.upcase/1))
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects invalid email format" do
      assert {:error, cs} = Accounts.register_user(%{email: "notanemail", password: "superSecureP@ss1"})
      assert %{email: [_]} = errors_on(cs)
    end

    test "rejects short password" do
      assert {:error, cs} = Accounts.register_user(%{email: "x@example.com", password: "short"})
      assert %{password: [_]} = errors_on(cs)
    end
  end

  # ---------------------------------------------------------------------------
  # get_user_by_email_and_password/2
  # ---------------------------------------------------------------------------

  describe "get_user_by_email_and_password/2" do
    test "returns user for valid credentials" do
      attrs = valid_user_attrs()
      {:ok, user} = Accounts.register_user(attrs)
      assert found = Accounts.get_user_by_email_and_password(attrs.email, attrs.password)
      assert found.id == user.id
    end

    test "returns nil for wrong password" do
      attrs = valid_user_attrs()
      {:ok, _} = Accounts.register_user(attrs)
      refute Accounts.get_user_by_email_and_password(attrs.email, "wrong-password-x")
    end

    test "returns nil for unknown email" do
      refute Accounts.get_user_by_email_and_password("no@one.com", "whatever")
    end
  end

  # ---------------------------------------------------------------------------
  # Session token lifecycle
  # ---------------------------------------------------------------------------

  describe "session tokens" do
    setup do
      attrs = valid_user_attrs()
      {:ok, user} = Accounts.register_user(attrs)
      %{user: user}
    end

    test "generate → retrieve → delete", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)
      assert found = Accounts.get_user_by_session_token(token)
      assert found.id == user.id

      :ok = Accounts.delete_user_session_token(token)
      refute Accounts.get_user_by_session_token(token)
    end

    test "expired tokens return nil", %{user: user} do
      # Force-insert a token with an old timestamp.
      token = :crypto.strong_rand_bytes(32)
      hashed = :crypto.hash(:sha256, token)

      NexusDownfall.Repo.insert!(%NexusDownfall.Accounts.UserToken{
        token: hashed,
        context: "session",
        user_id: user.id,
        inserted_at: ~U[2000-01-01 00:00:00Z]
      })

      refute Accounts.get_user_by_session_token(token)
    end
  end
end
