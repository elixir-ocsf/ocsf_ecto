defmodule OCSF.Ecto do
  @moduledoc """
  Postgres Ecto adapter for the OCSF Elixir library.

  Provides `OCSF.Sink` implementation backed by Postgres, with Cloak
  field-level encryption for PII attributes (`:contact`, `:identity`
  data classes).

  See `OCSF.Ecto.Repo`, `OCSF.Ecto.Event`, `OCSF.Ecto.Sink`.
  """
end
