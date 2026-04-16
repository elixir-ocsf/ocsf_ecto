defmodule OCSF.Ecto.Event do
  @moduledoc """
  Ecto schema for the `ocsf_event__logs` Postgres table.

  Flat projection of a canonical `%OCSF.Event{}` using the `__`
  segment separator (SPEC §6): nested paths like `metadata.product.name`
  become single columns (`metadata__product__name`). Corresponds to
  the OCSF
  [Base Event](https://schema.ocsf.io/1.8.0/classes/base_event) and
  the objects it embeds (`metadata`, `user`, `http_request`,
  `src_endpoint`, `dst_endpoint`, `service`).

  The schema itself is declarative and has no public functions —
  writes are performed by `OCSF.Ecto.Sink.write/1` via
  `Ecto.Repo.insert_all/3`.

  ## Primary key

  `:id` is a `:binary_id` seeded from the event's `metadata.uid` so
  the OCSF event UID IS the row UID. This enables
  `on_conflict: :nothing, conflict_target: :id` idempotent replays
  in the sink.

  ## Encrypted columns

  The following columns use `OCSF.Ecto.Types.EncryptedString` and
  are encrypted at rest via Cloak:

  - `user__name` (`:contact` / `:identity` classes)
  - `user__email_addr` (`:contact` / `:identity` classes)

  ## Custom types

  - `OCSF.Ecto.Types.Inet` on `src_endpoint__ip`, `dst_endpoint__ip`
  - `OCSF.Ecto.Types.EncryptedString` on encrypted PII columns

  See `OCSF.Ecto.Sink` for the write path and `OCSF.Event` for the
  canonical nested struct shape.
  """

  use Ecto.Schema

  alias OCSF.Ecto.Types.EncryptedString

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "ocsf_event__logs" do
    field :time, :utc_datetime_usec

    # metadata
    field :metadata__uid, :binary_id
    field :metadata__version, :string
    field :metadata__product__name, :string
    field :metadata__correlation_uid, :binary_id
    field :metadata__trace_uid, :string
    field :metadata__span_uid, :string
    field :metadata__event_code, :string

    # classification
    field :category_uid, :integer
    field :class_uid, :integer
    field :type_uid, :integer
    field :activity_id, :integer
    field :severity_id, :integer
    field :status_id, :integer
    field :status_detail, :string
    field :auth_protocol_id, :integer

    # user (PII encrypted)
    field :user__uid, :binary_id
    field :user__name, EncryptedString
    field :user__email_addr, EncryptedString
    field :user__org__uid, :string

    # http
    field :http_request__url, :string
    field :http_request__user_agent, :string
    field :http_request__http_method, :string

    # network (only when policy allows)
    field :src_endpoint__ip, OCSF.Ecto.Types.Inet
    field :dst_endpoint__ip, OCSF.Ecto.Types.Inet
    field :dst_endpoint__hostname, :string

    # service
    field :service__name, :string

    # extension
    field :unmapped, :map, default: %{}

    timestamps(updated_at: false, inserted_at: :inserted_at, type: :utc_datetime_usec)
  end
end
