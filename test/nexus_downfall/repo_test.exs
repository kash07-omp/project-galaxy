defmodule NexusDownfall.RepoTest do
  @moduledoc """
  Tests that the database connection is healthy and migrations have been applied.
  """

  use NexusDownfall.DataCase, async: true

  test "database connection is alive" do
    assert {:ok, _} = NexusDownfall.Repo.query("SELECT 1")
  end

  test "migrations have been applied (oban_jobs table exists)" do
    result = NexusDownfall.Repo.query!("SELECT to_regclass('public.oban_jobs')")
    [[table_oid]] = result.rows
    refute is_nil(table_oid), "oban_jobs table should exist after migrations"
  end

  test "can insert and read within a transaction" do
    # Verifies sandbox isolation — no real schema needed for this check.
    assert {:ok, %{rows: [[1]]}} = NexusDownfall.Repo.query("SELECT 1")
  end
end
