defmodule NexusDownfall.DataCase do
  @moduledoc """
  ExUnit case template for tests that interact with the database.

  Wraps each test in a transaction that is rolled back at the end,
  keeping the DB clean between tests. Use `async: true` when tests
  do not share mutable state.

  Usage:
      use NexusDownfall.DataCase, async: true
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias NexusDownfall.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import NexusDownfall.DataCase
    end
  end

  @doc """
  Converts changeset errors to a map of field => [message] for assertions.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  setup tags do
    NexusDownfall.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(NexusDownfall.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
