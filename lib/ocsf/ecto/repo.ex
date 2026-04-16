defmodule OCSF.Ecto.Repo do
  @moduledoc """
  Ecto Postgres repository for OCSF events.

  Configured via `config :ocsf_ecto, OCSF.Ecto.Repo, ...` — see
  `config/dev.exs` and `config/test.exs` for examples.
  """

  use Ecto.Repo,
    otp_app: :ocsf_ecto,
    adapter: Ecto.Adapters.Postgres
end
