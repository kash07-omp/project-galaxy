defmodule NexusDownfall.Accounts do
  @moduledoc """
  Accounts context.

  Manages global user accounts, authentication (registration, login, logout),
  sessions and universe membership (`UniverseUser`).

  Telemetry events emitted:
  - `[:nexus_downfall, :accounts, :user_registered]`
  - `[:nexus_downfall, :accounts, :user_logged_in]`
  - `[:nexus_downfall, :accounts, :universe_joined]`

  ## Phase roadmap
  - Phase 0: Module stub (structure only).
  - Phase 1: Full authentication, `User`, `UniverseUser` schemas, join-universe flow.
  """

  import Ecto.Query

  alias NexusDownfall.Repo
  alias NexusDownfall.Accounts.{User, UserToken, UniverseUser}

  # ---------------------------------------------------------------------------
  # User registration & retrieval
  # ---------------------------------------------------------------------------

  @doc "Returns a registration changeset (no hashing, no DB uniqueness check)."
  def change_user_registration(%User{} = user \\ %User{}, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  @doc """
  Registers a new user. Emits `[:nexus_downfall, :accounts, :user_registered]`.
  """
  def register_user(attrs) do
    result = %User{} |> User.registration_changeset(attrs) |> Repo.insert()

    case result do
      {:ok, user} ->
        :telemetry.execute(
          [:nexus_downfall, :accounts, :user_registered],
          %{count: 1},
          %{user_id: user.id}
        )

        {:ok, user}

      error ->
        error
    end
  end

  @doc "Gets a user by email address."
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Gets a user by email + password. Returns the `%User{}` on success, `nil` on failure.

  Emits `[:nexus_downfall, :accounts, :user_logged_in]` on success.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: String.downcase(email))

    if User.valid_password?(user, password) do
      :telemetry.execute(
        [:nexus_downfall, :accounts, :user_logged_in],
        %{count: 1},
        %{user_id: user.id}
      )

      user
    end
  end

  @doc "Gets a user by id. Raises if not found."
  def get_user!(id), do: Repo.get!(User, id)

  # ---------------------------------------------------------------------------
  # Session tokens
  # ---------------------------------------------------------------------------

  @doc """
  Generates a session token. Returns `raw_token` — store in the cookie.
  The hashed version is persisted in `user_tokens`.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc "Resolves a raw session token to a `%User{}`, or `nil` if expired/invalid."
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc "Deletes a session token (logout from current device)."
  def delete_user_session_token(token) do
    hashed = :crypto.hash(:sha256, token)
    Repo.delete_all(from t in UserToken, where: t.token == ^hashed)
    :ok
  end

  @doc "Deletes all session tokens (logout from all devices)."
  def delete_all_user_session_tokens(user) do
    Repo.delete_all(UserToken.by_user_and_contexts_query(user, ["session"]))
    :ok
  end

  # ---------------------------------------------------------------------------
  # Universe membership
  # ---------------------------------------------------------------------------

  @doc "Returns a `UniverseUser` changeset for the join-universe form."
  def change_join_universe(%UniverseUser{} = uu \\ %UniverseUser{}, attrs \\ %{}) do
    UniverseUser.join_changeset(uu, attrs)
  end

  @doc """
  Creates a `UniverseUser` record, linking `user` to `universe`.

  Emits `[:nexus_downfall, :accounts, :universe_joined]` on success.
  """
  def join_universe(user, universe, attrs) do
    string_attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    merged =
      Map.merge(string_attrs, %{
        "user_id" => user.id,
        "universe_id" => universe.id,
        "joined_at" => DateTime.utc_now() |> DateTime.truncate(:second)
      })

    result = %UniverseUser{} |> UniverseUser.join_changeset(merged) |> Repo.insert()

    case result do
      {:ok, uu} ->
        :telemetry.execute(
          [:nexus_downfall, :accounts, :universe_joined],
          %{count: 1},
          %{user_id: user.id, universe_id: universe.id, universe_user_id: uu.id}
        )

        {:ok, uu}

      error ->
        error
    end
  end

  @doc "Returns the `UniverseUser` for a user in a universe, or `nil`."
  def get_universe_user(user_id, universe_id) do
    Repo.get_by(UniverseUser, user_id: user_id, universe_id: universe_id)
  end

  @doc "Returns all `UniverseUser` records for `user_id`, preloading `:universe`."
  def list_universe_memberships(user_id) do
    Repo.all(from uu in UniverseUser, where: uu.user_id == ^user_id, preload: [:universe])
  end
end
