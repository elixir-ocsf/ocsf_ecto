defmodule OCSF.Ecto.Repo.Migrations.CreateOcsfEventLogs do
  # Library self-test migration. Exists so `mix ecto.migrate` works
  # against OCSF.Ecto.Repo in dev / test. Not part of the public API —
  # consumer apps write their own one-liner that delegates to
  # OCSF.Ecto.Migration.up/down (see SPEC §11.3).
  use Ecto.Migration

  def up, do: OCSF.Ecto.Migration.up()
  def down, do: OCSF.Ecto.Migration.down()
end
