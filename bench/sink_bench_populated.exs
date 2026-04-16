Application.ensure_all_started(:ocsf_ecto)

count = OCSF.Ecto.Repo.aggregate(OCSF.Ecto.Event, :count)
IO.puts("Starting benchmark with #{count} existing rows in table\n")

build_event = fn ->
  {:ok, event} =
    OCSF.Events.Authentication.logon(
      user: %{
        uid: OCSF.UUID.v7_string(),
        name: "Jane Doe",
        email_addr: "jane@example.com",
        org: %{uid: "acme"}
      },
      service: %{name: "Auth"},
      status: :Success,
      severity: :Informational,
      auth_protocol: :"OAUTH 2.0"
    )

  event
end

build_batch = fn n -> for _ <- 1..n, do: build_event.() end

single_event = build_event.()
batch_10 = build_batch.(10)
batch_100 = build_batch.(100)
batch_500 = build_batch.(500)

Benchee.run(
  %{
    "Sink.row_for/1 (no DB)" => fn -> OCSF.Ecto.Sink.row_for(single_event) end,
    "Sink.write/1 — 1 event" => fn -> OCSF.Ecto.Sink.write([single_event]) end,
    "Sink.write/1 — 10 events" => fn -> OCSF.Ecto.Sink.write(batch_10) end,
    "Sink.write/1 — 100 events" => fn -> OCSF.Ecto.Sink.write(batch_100) end,
    "Sink.write/1 — 500 events" => fn -> OCSF.Ecto.Sink.write(batch_500) end
  },
  time: 5,
  warmup: 2,
  print: [configuration: false]
)
