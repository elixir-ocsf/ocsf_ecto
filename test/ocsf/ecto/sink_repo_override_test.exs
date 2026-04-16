defmodule OCSF.Ecto.SinkRepoOverrideTest do
  # async: false — mutates the :ocsf_ecto, :repo application env,
  # which is global state and would race with any concurrent
  # Sink.repo/0 caller in an async: true suite.
  use ExUnit.Case, async: false

  alias OCSF.Ecto.Sink

  describe "repo/0 override via :ocsf_ecto, :repo" do
    setup do
      on_exit(fn -> Application.delete_env(:ocsf_ecto, :repo) end)
      :ok
    end

    test "returns the host-configured Repo when set" do
      Application.put_env(:ocsf_ecto, :repo, OCSF.Ecto.SinkRepoOverrideTest.FakeRepo)
      assert Sink.repo() == OCSF.Ecto.SinkRepoOverrideTest.FakeRepo
    end

    test "falls back to OCSF.Ecto.Repo when unset" do
      Application.delete_env(:ocsf_ecto, :repo)
      assert Sink.repo() == OCSF.Ecto.Repo
    end
  end
end
