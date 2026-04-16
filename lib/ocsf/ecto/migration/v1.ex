defmodule OCSF.Ecto.Migration.V1 do
  @moduledoc """
  v1 migration — base `ocsf_event__logs` table and indexes.

  Mirrors the DDL specified in SPEC §11.1. The table is created
  via `create_if_not_exists/1` and every index via
  `create_if_not_exists/1` so re-running `up/1` is safe.

  > **v0 note:** `OCSF.Ecto.Migration` guards `:prefix` / `:table`
  > to the default values, so V1 uses compile-time atoms rather
  > than constructing them at runtime. Later versions that support
  > overrides will take `opts` into account; the `@behaviour`
  > signature stays identical.

  See `OCSF.Ecto.Migration` for the public entry point.
  """

  use Ecto.Migration
  @behaviour OCSF.Ecto.Migration.Version

  @table :ocsf_event__logs

  # Compile-time index names — one atom per entry, no runtime interpolation.
  @indexes [
    {[:time], :ocsf_event__logs__time__idx},
    {[:user__uid], :ocsf_event__logs__user__uid__idx},
    {[:user__org__uid], :ocsf_event__logs__user__org__uid__idx},
    {[:class_uid, :activity_id], :ocsf_event__logs__class__idx},
    {[:type_uid], :ocsf_event__logs__type_uid__idx},
    {[:metadata__correlation_uid], :ocsf_event__logs__correlation_uid__idx},
    {[:metadata__trace_uid], :ocsf_event__logs__trace_uid__idx}
  ]

  @impl true
  def up(_opts) do
    create_if_not_exists table(@table, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :time, :utc_datetime_usec, null: false

      add :metadata__uid, :binary_id, null: false
      add :metadata__version, :text, null: false
      add :metadata__product__name, :text
      add :metadata__correlation_uid, :binary_id
      add :metadata__trace_uid, :text
      add :metadata__span_uid, :text
      add :metadata__event_code, :text

      add :category_uid, :smallint, null: false
      add :class_uid, :integer, null: false
      add :type_uid, :bigint, null: false
      add :activity_id, :smallint, null: false
      add :severity_id, :smallint, null: false
      add :status_id, :smallint, null: false
      add :status_detail, :text
      add :auth_protocol_id, :smallint

      add :user__uid, :binary_id
      add :user__name, :binary
      add :user__email_addr, :binary
      add :user__org__uid, :text

      add :http_request__url, :text
      add :http_request__user_agent, :text
      add :http_request__http_method, :text

      add :src_endpoint__ip, :inet
      add :dst_endpoint__ip, :inet
      add :dst_endpoint__hostname, :text

      add :service__name, :text

      add :unmapped, :map, null: false, default: %{}

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("now()")
    end

    for {cols, name} <- @indexes do
      create_if_not_exists index(@table, cols, name: name)
    end

    :ok
  end

  @impl true
  def down(_opts) do
    drop_if_exists table(@table)
    :ok
  end
end
