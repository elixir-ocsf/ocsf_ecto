defmodule OCSF.Ecto.Sink do
  @moduledoc """
  Postgres sink implementation of the `OCSF.Sink` behaviour.

  Writes `%OCSF.Event{}` structs to the `ocsf_event__logs` table via
  `Ecto.Repo.insert_all/3`. Applies the configured `OCSF.Policy` for
  field-level redaction before insert. PII fields (`user__name`,
  `user__email_addr`) are transparently encrypted via Cloak.

  ## Configuration

      config :ocsf_ecto, OCSF.Ecto.Sink,
        policy: %OCSF.Policy{
          allow: [:identifier, :tenant, :taxonomic, :temporal,
                  :contact, :identity],
          deny:  [:network],
          transform: []
        }

  ## Example

      {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
      OCSF.Ecto.Sink.write([event])
      #=> :ok

  See `OCSF.Ecto.Event`, `OCSF.Ecto.Repo`.
  """

  alias OCSF.Ecto.Event, as: EctoEvent
  alias OCSF.Ecto.Repo

  @behaviour OCSF.Sink

  @default_policy %OCSF.Policy{
    allow: [:identifier, :tenant, :taxonomic, :temporal, :contact, :identity],
    deny: [:network],
    transform: []
  }

  @doc """
  Writes a batch of OCSF events to Postgres.

  Each event is run through the configured `OCSF.Policy` (denied
  classes become `nil`), projected to the flat `ocsf_event__logs`
  row shape, and inserted via `Ecto.Repo.insert_all/3` with
  `on_conflict: :nothing` on the `:id` column. Replaying the same
  event UID is therefore a no-op.

  Returns `:ok` when the insert succeeds (even if no new rows were
  written due to conflict), or `{:error, exception}` on failure.

  ## Examples

      {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
      :ok = OCSF.Ecto.Sink.write([event])

      # Replay is idempotent on metadata.uid
      :ok = OCSF.Ecto.Sink.write([event])
  """
  @impl true
  @spec write([OCSF.Event.t()]) :: :ok | {:error, term}
  def write(events) when is_list(events) do
    rows = Enum.map(events, &row_for/1)

    case Repo.insert_all(EctoEvent, rows, on_conflict: :nothing, conflict_target: :id) do
      {_count, _} -> :ok
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Projects an `%OCSF.Event{}` to the raw row map inserted by `write/1`.

  Applies the sink's policy, encrypts PII via Cloak, and returns
  the keyword-indexed map passed to `Ecto.Repo.insert_all/3`.
  Exposed for diagnostic and test use — prefer `write/1` in
  application code.

  ## Examples

      {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
      row = OCSF.Ecto.Sink.row_for(event)
      row.class_uid
      #=> 3002
      row.metadata__uid == event.metadata.uid
      #=> true
  """
  @impl true
  @spec row_for(OCSF.Event.t()) :: map
  def row_for(%OCSF.Event{} = event) do
    redacted = OCSF.Policy.apply(policy(), event)
    now = DateTime.utc_now()

    %{
      id: redacted.metadata.uid,
      time: redacted.time,
      metadata__uid: redacted.metadata.uid,
      metadata__version: redacted.metadata.version,
      metadata__product__name: get_in_safe(redacted, [:metadata, :product, :name]),
      metadata__correlation_uid: redacted.metadata.correlation_uid,
      metadata__trace_uid: redacted.metadata.trace_uid,
      metadata__span_uid: redacted.metadata.span_uid,
      metadata__event_code: redacted.metadata.event_code,
      category_uid: redacted.category_uid,
      class_uid: redacted.class_uid,
      type_uid: redacted.type_uid,
      activity_id: redacted.activity_id,
      severity_id: redacted.severity_id,
      status_id: redacted.status_id,
      status_detail: redacted.status_detail,
      auth_protocol_id: redacted.auth_protocol_id,
      user__uid: get_in_safe(redacted, [:user, :uid]),
      user__name: get_in_safe(redacted, [:user, :name]),
      user__email_addr: get_in_safe(redacted, [:user, :email_addr]),
      user__org__uid: get_in_safe(redacted, [:user, :org, :uid]),
      http_request__url: get_in_safe(redacted, [:http_request, :url]),
      http_request__user_agent: get_in_safe(redacted, [:http_request, :user_agent]),
      http_request__http_method: get_in_safe(redacted, [:http_request, :http_method]),
      src_endpoint__ip: get_in_safe(redacted, [:src_endpoint, :ip]),
      dst_endpoint__ip: get_in_safe(redacted, [:dst_endpoint, :ip]),
      dst_endpoint__hostname: get_in_safe(redacted, [:dst_endpoint, :hostname]),
      service__name: get_in_safe(redacted, [:service, :name]),
      unmapped: redacted.unmapped || %{},
      inserted_at: now
    }
  end

  @doc """
  Returns the `OCSF.Policy` applied to every write.

  Resolved from `Application.get_env(:ocsf_ecto, OCSF.Ecto.Sink)`
  at call time. Falls back to a deny-`:network`, allow-PII default
  when no config is provided.

  ## Examples

      %OCSF.Policy{} = OCSF.Ecto.Sink.policy()
  """
  @impl true
  @spec policy() :: OCSF.Policy.t()
  def policy do
    config = Application.get_env(:ocsf_ecto, __MODULE__, [])
    Keyword.get(config, :policy, @default_policy)
  end

  @doc """
  Probes the underlying Repo and returns a sink health signal.

  Issues a `SELECT 1` against Postgres. Returns `:ok` when the
  query succeeds, or `{:down, reason}` when the Repo is unavailable
  or raises.

  ## Examples

      :ok = OCSF.Ecto.Sink.health()
  """
  @impl true
  @spec health() :: OCSF.Sink.health()
  def health do
    case Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, reason} -> {:down, reason}
    end
  rescue
    error -> {:down, error}
  end

  defp get_in_safe(nil, _path), do: nil

  defp get_in_safe(data, [key]) do
    case data do
      %{} -> Map.get(data, key)
      _ -> nil
    end
  end

  defp get_in_safe(data, [key | rest]) do
    case data do
      %{} ->
        data
        |> Map.get(key)
        |> get_in_safe(rest)

      _ ->
        nil
    end
  end
end
