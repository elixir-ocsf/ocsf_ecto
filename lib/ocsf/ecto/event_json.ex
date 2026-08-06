defimpl Jason.Encoder, for: OCSF.Ecto.Event do
  @moduledoc """
  Encode a stored `OCSF.Ecto.Event` row directly to canonical OCSF JSON.

  `Jason.encode!(row)` reconstructs the nested OCSF event from the flat
  columns via `OCSF.Ecto.Event.to_ocsf_map/1` and encodes it — so a
  persisted row serializes exactly like the event it came from, the
  classic Ecto + Jason pattern.
  """

  def encode(row, opts) do
    row
    |> OCSF.Ecto.Event.to_ocsf_map()
    |> Jason.Encode.map(opts)
  end
end
