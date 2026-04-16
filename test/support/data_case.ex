defmodule OCSF.Ecto.DataCase do
  @moduledoc """
  Test case template for tests that interact with the database.

  Wraps each test in a sandbox transaction that rolls back on exit —
  no cleanup code needed. Sets `async: true` for test modules that
  don't spawn processes accessing the database.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias OCSF.Ecto.DataCase
  alias OCSF.Ecto.Repo

  using do
    quote do
      alias OCSF.Ecto.Repo
      import Ecto
      import Ecto.Query
      import OCSF.Ecto.DataCase
    end
  end

  setup tags do
    DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Set up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end
