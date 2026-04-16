defmodule OCSF.Ecto.Repo.Migrations.CreateOcsfEventLogs do
  use Ecto.Migration

  def change do
    create table(:ocsf_event__logs, primary_key: false) do
      # identity & time
      add :id, :binary_id, primary_key: true
      add :time, :utc_datetime_usec, null: false

      # metadata
      add :metadata__uid, :binary_id, null: false
      add :metadata__version, :text, null: false
      add :metadata__product__name, :text
      add :metadata__correlation_uid, :binary_id
      add :metadata__trace_uid, :text
      add :metadata__span_uid, :text
      add :metadata__event_code, :text

      # classification
      add :category_uid, :smallint, null: false
      add :class_uid, :integer, null: false
      add :type_uid, :bigint, null: false
      add :activity_id, :smallint, null: false
      add :severity_id, :smallint, null: false
      add :status_id, :smallint, null: false
      add :status_detail, :text
      add :auth_protocol_id, :smallint

      # user (AES for :contact / :identity)
      add :user__uid, :binary_id
      add :user__name, :binary
      add :user__email_addr, :binary
      add :user__org__uid, :text

      # http
      add :http_request__url, :text
      add :http_request__user_agent, :text
      add :http_request__http_method, :text

      # network (deny-by-default at sink; here when policy allows)
      add :src_endpoint__ip, :inet
      add :dst_endpoint__ip, :inet
      add :dst_endpoint__hostname, :text

      # service
      add :service__name, :text

      # extension
      add :unmapped, :map, null: false, default: %{}

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:ocsf_event__logs, [:time], name: :ocsf_event__logs__time__idx)
    create index(:ocsf_event__logs, [:user__uid], name: :ocsf_event__logs__user__uid__idx)

    create index(:ocsf_event__logs, [:user__org__uid],
             name: :ocsf_event__logs__user__org__uid__idx
           )

    create index(:ocsf_event__logs, [:class_uid, :activity_id],
             name: :ocsf_event__logs__class__idx
           )

    create index(:ocsf_event__logs, [:metadata__correlation_uid],
             name: :ocsf_event__logs__correlation_uid__idx
           )

    create index(:ocsf_event__logs, [:metadata__trace_uid],
             name: :ocsf_event__logs__trace_uid__idx
           )

    create index(:ocsf_event__logs, [:type_uid], name: :ocsf_event__logs__type_uid__idx)
  end
end
