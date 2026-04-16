defmodule OCSF.Ecto.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OCSF.Ecto.Vault,
      OCSF.Ecto.Repo
    ]

    opts = [strategy: :one_for_one, name: OCSF.Ecto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
