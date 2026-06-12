defmodule OCSF.Ecto.IngestIntegrationTest do
  @moduledoc """
  End-to-end: events dispatched through the `ocsf_ingest` pipeline are written
  to Postgres through `OCSF.Ecto.Sink`. Proves the `OCSF.Sink` contract holds
  across the two libraries.
  """

  # async: false — the Broadway pipeline writes from spawned processes, so the
  # sandbox must run in shared mode (DataCase sets shared: not async).
  use OCSF.Ecto.DataCase, async: false

  alias OCSF.Ecto.Event, as: EctoEvent
  alias OCSF.Ecto.TelemetryRelay
  alias OCSF.Events.Authentication

  @sink OCSF.Ecto.Sink

  setup do
    start_supervised!(
      {OCSF.Ingest.SinkSupervisor,
       {@sink,
        [
          batch_size: 10,
          batch_timeout_ms: 20,
          max_queue_size: 1000,
          max_global_queue_size: 10_000
        ]}}
    )

    TelemetryRelay.attach([:ocsf, :ingest, :batch], self())
    on_exit(fn -> TelemetryRelay.detach([:ocsf, :ingest, :batch], self()) end)
    :ok
  end

  defp build_event do
    {:ok, event} =
      Authentication.logon(
        user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Jane Doe",
          email_addr: "jane@example.com",
          org: %{uid: "acme"}
        },
        service: %{name: "Cryptr Auth"},
        status: :Success,
        severity: :Informational,
        auth_protocol: :"OAUTH 2.0"
      )

    event
  end

  test "a dispatched event is persisted through the Ecto sink" do
    event = build_event()
    assert :ok = OCSF.Ingest.dispatch(event, sink: @sink)

    assert_receive {:telemetry, [:ocsf, :ingest, :batch], %{count: 1},
                    %{sink: @sink, result: :ok}},
                   5000

    [row] = Repo.all(EctoEvent)
    assert row.id == event.metadata.uid
    assert row.class_uid == 3002
    assert row.user__org__uid == "acme"
    # PII round-trips through the Cloak vault
    assert row.user__name == "Jane Doe"
  end

  test "replaying the same event stays idempotent end-to-end" do
    event = build_event()

    assert :ok = OCSF.Ingest.dispatch(event, sink: @sink)
    assert_receive {:telemetry, [:ocsf, :ingest, :batch], %{count: 1}, %{result: :ok}}, 5000

    assert :ok = OCSF.Ingest.dispatch(event, sink: @sink)
    assert_receive {:telemetry, [:ocsf, :ingest, :batch], %{count: 1}, %{result: :ok}}, 5000

    assert Repo.aggregate(EctoEvent, :count) == 1
  end
end
