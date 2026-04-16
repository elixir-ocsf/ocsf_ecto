defmodule OCSF.Ecto.Migration.Version do
  @moduledoc """
  Behaviour implemented by every versioned `ocsf_ecto` migration.

  Versions are hand-authored under `OCSF.Ecto.Migration.V_n` and
  dispatched by `OCSF.Ecto.Migration.up/1` / `down/1`. Each `V_n`
  module receives a resolved option map so it does not have to
  repeat default handling.

  See `OCSF.Ecto.Migration` for the public API and SPEC §11.3 for
  the versioning contract.
  """

  @typedoc "Resolved migration options, as assembled by `OCSF.Ecto.Migration`."
  @type opts :: %{prefix: String.t(), table: String.t(), schema: String.t() | nil}

  @callback up(opts) :: :ok
  @callback down(opts) :: :ok
end
