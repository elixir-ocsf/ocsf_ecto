defmodule OCSF.Ecto.Migration.V2 do
  @moduledoc """
  v2 migration — completeness columns for the non-PII sub-objects and
  list fields, so a stored row can round-trip to canonical OCSF JSON
  (see `OCSF.Ecto.Event.to_ocsf_map/1`).

  Adds, in one schema bump:

  - plain `jsonb` columns for the non-PII cardinality-1 sub-objects that
    are not already flattened (`iam_role`, `updated_role`, `group`,
    `api`) and for the list-valued fields (`groups`, `iam_roles`,
    `privileges`, `resources`, `metadata__profiles`), plus a `raw_data`
    text column;
  - **encrypted** `:binary` columns for the PII-bearing sub-objects
    (`actor`, `updated_user`, `entity`), which carry name/email — a plain
    `jsonb` column would store PII in cleartext at rest, so these use
    `OCSF.Ecto.Types.EncryptedMap` (Cloak) instead.

  See `OCSF.Ecto.Migration` for the public entry point.
  """

  use Ecto.Migration
  @behaviour OCSF.Ecto.Migration.Version

  @table :ocsf_event__logs

  # Non-PII jsonb columns (objects and lists).
  @jsonb_columns [
    :iam_role,
    :updated_role,
    :group,
    :api,
    :groups,
    :iam_roles,
    :privileges,
    :resources,
    :metadata__profiles
  ]

  # PII-bearing sub-objects — stored as Cloak-encrypted binary.
  @encrypted_columns [:actor, :updated_user, :entity]

  @impl true
  def up(_opts) do
    alter table(@table) do
      for column <- @jsonb_columns do
        add_if_not_exists column, :map
      end

      for column <- @encrypted_columns do
        add_if_not_exists column, :binary
      end

      add_if_not_exists :raw_data, :text
    end

    :ok
  end

  @impl true
  def down(_opts) do
    alter table(@table) do
      for column <- @jsonb_columns ++ @encrypted_columns do
        remove_if_exists column, :binary
      end

      remove_if_exists :raw_data, :text
    end

    :ok
  end
end
