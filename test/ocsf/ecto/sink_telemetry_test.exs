defmodule OCSF.Ecto.SinkTelemetryTest do
  # async: false — attaching/detaching global telemetry handlers races
  # with any other test attaching on the same prefix. See
  # TESTING_GUIDELINES.md §4.2.
  use OCSF.Ecto.DataCase, async: false

  alias OCSF.Ecto.Sink
  alias OCSF.Ecto.TestTelemetryHandler
  alias OCSF.Events.Authentication

  @events [
    [:ocsf_ecto, :sink, :write, :start],
    [:ocsf_ecto, :sink, :write, :stop],
    [:ocsf_ecto, :sink, :write, :exception]
  ]

  setup context do
    handler_id = "sink-telemetry-#{inspect(context.test)}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        @events,
        &TestTelemetryHandler.handle_event/4,
        %{pid: self()}
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  describe "write/1 telemetry — successful write" do
    test "emits :start with system_time, monotonic_time, count and sink" do
      :ok = Sink.write([build_event()])

      assert_receive {:telemetry, [:ocsf_ecto, :sink, :write, :start], m, meta}
      assert is_integer(m.system_time)
      assert is_integer(m.monotonic_time)
      assert meta.count == 1
      assert meta.sink == Sink
    end

    test "emits :stop with duration, count, sink and result: :ok" do
      :ok = Sink.write([build_event()])

      assert_receive {:telemetry, [:ocsf_ecto, :sink, :write, :stop], m, meta}
      assert is_integer(m.duration) and m.duration >= 0
      assert meta.count == 1
      assert meta.sink == Sink
      assert meta.result == :ok
    end

    test ":count reflects the batch size" do
      :ok = Sink.write([build_event(), build_event(), build_event()])

      assert_receive {:telemetry, [:ocsf_ecto, :sink, :write, :start], _, %{count: 3}}
      assert_receive {:telemetry, [:ocsf_ecto, :sink, :write, :stop], _, %{count: 3}}
    end
  end

  describe "write/1 telemetry — error path" do
    # async: false + DataCase shares the sandbox, so spawning a caller
    # without ownership (the trick used in `sink_test.exs`) is not
    # available here. Instead, pass a non-event struct so `row_for/1`
    # fails its pattern match and the Sink's rescue clause converts
    # the raise into `{:error, _}`.
    test "emits :stop with result: :error when the write fails" do
      assert {:error, %FunctionClauseError{}} = Sink.write([%{not_an_event: true}])

      assert_receive {:telemetry, [:ocsf_ecto, :sink, :write, :stop], _, %{result: :error}}
    end
  end

  # -- helpers --

  defp build_event(opts \\ []) do
    default_opts = [
      user: %{
        uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
        org: %{uid: "acme"}
      },
      service: %{name: "Test"},
      status: :Success,
      severity: :Informational,
      auth_protocol: :SAML
    ]

    {:ok, event} = Authentication.logon(Keyword.merge(default_opts, opts))
    event
  end
end
