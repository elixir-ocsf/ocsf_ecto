defmodule OCSF.Ecto.Migration.V1 do
  @moduledoc """
  v1 migration — base `ocsf_event__logs` table and indexes.

  Mirrors the DDL specified in SPEC §11.1. The table is created
  via `create_if_not_exists/1` and every index via
  `create_if_not_exists/1` so re-running `up/1` is safe.

  See `OCSF.Ecto.Migration` for the public entry point.
  """

  use Ecto.Migration
  @behaviour OCSF.Ecto.Migration.Version

  @indexes [
    {[:time], "time__idx"},
    {[:user__uid], "user__uid__idx"},
    {[:user__org__uid], "user__org__uid__idx"},
    {[:class_uid, :activity_id], "class__idx"},
    {[:type_uid], "type_uid__idx"},
    {[:metadata__correlation_uid], "correlation_uid__idx"},
    {[:metadata__trace_uid], "trace_uid__idx"}
  ]

  @impl true
  def up(%{prefix: prefix, table: base}) do
    table_name = String.to_atom(prefix <> base)

    create_if_not_exists table(table_name, primary_key: false) do
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

    for {cols, suffix} <- @indexes do
      create_if_not_exists index(table_name, cols, name: index_name(prefix, base, suffix))
    end

    :ok
  end

  @impl true
  def down(%{prefix: prefix, table: base}) do
    drop_if_exists table(String.to_atom(prefix <> base))
    :ok
  end

  defp index_name(prefix, base, suffix), do: :"#{prefix}#{base}__#{suffix}"
end
