defmodule OCSF.Ecto.Types.Json do
  @moduledoc """
  Passthrough Ecto type for arbitrary JSON stored in a `jsonb` column.

  Unlike the built-in `:map` type, this accepts both JSON **objects**
  (maps) and JSON **arrays** (lists) unchanged, so it can back the
  completeness columns that hold either a single OCSF sub-object
  (`iam_role`, `group`, `api`, …) or a list (`groups`, `iam_roles`,
  `privileges`, `resources`, `metadata__profiles`).

  Values are stored and read back verbatim; the sink writes the
  OCSF-serialized sub-tree and `OCSF.Ecto.Event.to_ocsf_map/1` reads it
  back to rebuild the nested event. Non-PII only — PII-bearing
  sub-objects use an encrypted type instead (see the sink's PII notes).
  """

  use Ecto.Type

  @impl true
  def type, do: :map

  @impl true
  def cast(value), do: {:ok, value}

  @impl true
  def load(value), do: {:ok, value}

  @impl true
  def dump(value), do: {:ok, value}

  @impl true
  def embed_as(_format), do: :self
end
