defmodule NexusDownfall.Accounts.UserToken do
  @moduledoc """
  User session and confirmation tokens.

  Each token has a `context`:
  - `"session"` — long-lived bearer token stored in the cookie.
  - `"confirm"` — email confirmation (single-use).
  - `"reset_password"` — password reset (single-use).
  """

  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  # Session tokens are valid for 60 days.
  @session_validity_in_days 60

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    belongs_to :user, NexusDownfall.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a session token (stored as a hash; the raw token is sent to client).
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed = :crypto.hash(@hash_algorithm, token)

    {token,
     %NexusDownfall.Accounts.UserToken{
       token: hashed,
       context: "session",
       user_id: user.id
     }}
  end

  @doc """
  Returns the token with the given value and context if it has not expired.
  """
  def verify_session_token_query(token) do
    hashed = :crypto.hash(@hash_algorithm, token)
    days_ago = DateTime.add(DateTime.utc_now(), -@session_validity_in_days * 86_400)

    query =
      from token in NexusDownfall.Accounts.UserToken,
        join: user in assoc(token, :user),
        where:
          token.token == ^hashed and
            token.context == "session" and
            token.inserted_at > ^days_ago,
        select: user

    {:ok, query}
  end

  @doc """
  Returns the query to delete all session tokens for a user.
  """
  def by_user_and_contexts_query(user, :all) do
    from t in NexusDownfall.Accounts.UserToken, where: t.user_id == ^user.id
  end

  def by_user_and_contexts_query(user, contexts) when is_list(contexts) do
    from t in NexusDownfall.Accounts.UserToken,
      where: t.user_id == ^user.id and t.context in ^contexts
  end
end
