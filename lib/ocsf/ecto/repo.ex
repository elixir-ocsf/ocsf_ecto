defmodule OCSF.Ecto.Repo do
  @moduledoc """
  Ecto Postgres repository for OCSF events.

  Configured via `config :ocsf_ecto, OCSF.Ecto.Repo, ...` — see
  `config/dev.exs` and `config/test.exs` for examples.

  Host apps that already own an `Ecto.Repo` can disable this one by
  setting `config :ocsf_ecto, OCSF.Ecto.Repo, start: false`. The
  library's supervision tree then skips booting it, and the sink's
  Repo is resolved from `config :ocsf_ecto, :repo, MyApp.Repo`.
  """

  use Ecto.Repo,
    otp_app: :ocsf_ecto,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    if Keyword.get(config, :start, true) do
      {:ok, config}
    else
      :ignore
    end
  end
end
