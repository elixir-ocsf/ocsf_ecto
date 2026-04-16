Application.ensure_all_started(:ocsf_ecto)

target = String.to_integer(System.get_env("SEED_ROWS") || "1000000")
batch_size = 1000

IO.puts("Seeding #{target} rows in batches of #{batch_size}...")
start = System.monotonic_time(:millisecond)

build_event = fn ->
  {:ok, event} =
    OCSF.Events.Authentication.logon(
      user: %{
        uid: OCSF.UUID.v7_string(),
        name: "User #{:rand.uniform(1_000_000)}",
        email_addr: "user#{:rand.uniform(1_000_000)}@example.com",
        org: %{uid: "org-#{:rand.uniform(100)}"}
      },
      service: %{name: "Auth"},
      status: Enum.random([:Success, :Failure]),
      severity: :Informational,
      auth_protocol: Enum.random([:"OAUTH 2.0", :SAML, :OpenID])
    )

  event
end

batches = div(target, batch_size)

for i <- 1..batches do
  events = for _ <- 1..batch_size, do: build_event.()
  :ok = OCSF.Ecto.Sink.write(events)

  if rem(i, 10) == 0 do
    elapsed = System.monotonic_time(:millisecond) - start
    written = i * batch_size
    rate = written * 1000 / elapsed
    IO.puts("  #{written}/#{target} (#{:erlang.float_to_binary(rate, decimals: 0)} evt/s, #{div(elapsed, 1000)}s)")
  end
end

elapsed = System.monotonic_time(:millisecond) - start
count = OCSF.Ecto.Repo.aggregate(OCSF.Ecto.Event, :count)
IO.puts("\nDone. #{count} rows in table. Elapsed: #{div(elapsed, 1000)}s")
