defmodule OCSF.Ecto.Repo.Migrations.AddOcsfCompletenessColumns do
  # Library self-test migration for schema v2 (non-PII completeness
  # columns). Pinned to version 2; the base table is created by the
  # version-1 migration. Consumer apps write their own one-liner that
  # delegates to OCSF.Ecto.Migration.up(version: 2) (see SPEC §11.3).
  use Ecto.Migration

  def up, do: OCSF.Ecto.Migration.up(version: 2)
  def down, do: OCSF.Ecto.Migration.down(version: 2)
end
