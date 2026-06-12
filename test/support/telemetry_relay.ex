defmodule OCSF.Ecto.TelemetryRelay do
  @moduledoc false

  # Module-based telemetry handler that forwards events to a test pid.

  def attach(event, pid) do
    :telemetry.attach({__MODULE__, event, pid}, event, &__MODULE__.handle/4, pid)
  end

  def detach(event, pid) do
    :telemetry.detach({__MODULE__, event, pid})
  end

  def handle(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end
end
