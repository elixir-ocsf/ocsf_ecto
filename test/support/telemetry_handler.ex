defmodule OCSF.Ecto.TestTelemetryHandler do
  @moduledoc false

  # Module-based telemetry handler for tests. Forwards every event
  # to the pid stored in the handler config as a
  # `{:telemetry, event_name, measurements, metadata}` message.
  #
  # Per TESTING_GUIDELINES.md §5.4, never use anonymous functions
  # with `:telemetry.attach/4` — the telemetry library warns about
  # performance.

  def handle_event(event_name, measurements, metadata, %{pid: pid}) do
    send(pid, {:telemetry, event_name, measurements, metadata})
  end
end
