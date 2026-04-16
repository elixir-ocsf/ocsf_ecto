# Testing Guidelines

Testing conventions for the `ocsf_ecto` library, derived from
Elixir community best practices (Ecto, Broadway, ExUnit docs) and
adapted to this project's needs.

---

## 1. Principles

- **Tests are documentation.** A reader should understand what a
  module does by reading its tests alone. Test names describe
  behavior, not implementation.
- **Real Postgres, sandboxed.** Every DB-backed test runs against
  a real Postgres via `Ecto.Adapters.SQL.Sandbox`. We don't mock
  the Repo — mocks diverge from production behavior (especially
  for encryption and Postgres-specific types like `inet`).
- **Fast by default.** Every test module uses `async: true` unless
  it touches shared state (app config, telemetry handlers, the
  vault cipher config).
- **One assertion focus per test.** A test may have multiple
  `assert` lines to verify one logical outcome, but should not
  test two unrelated behaviors.
- **No test should depend on another.** Tests must pass in any
  order and in isolation. The sandbox rolls back every test, so
  there is no cross-test leakage.
- **Coverage is a floor, not a goal.** 90% minimum enforced by CI,
  100% the target. Meaningful tests matter more than line-counting.

---

## 2. File organization

### 2.1 Directory structure

```
test/
  ocsf/
    ecto/
      event_test.exs              # mirrors lib/ocsf/ecto/event.ex
      sink_test.exs               # mirrors lib/ocsf/ecto/sink.ex
      vault_test.exs              # mirrors lib/ocsf/ecto/vault.ex
      types/
        inet_test.exs             # mirrors lib/ocsf/ecto/types/inet.ex
        encrypted_string_test.exs
  support/
    data_case.ex                  # sandbox-backed ExUnit case template
    telemetry_handler.ex          # module-based test helpers
  test_helper.exs                 # Sandbox.mode(:manual); ExUnit.start()
```

### 2.2 File naming

- Test file path mirrors the source file:
  `lib/ocsf/ecto/sink.ex` -> `test/ocsf/ecto/sink_test.exs`.
- Test module name mirrors the source module with `Test` suffix:
  `OCSF.Ecto.Sink` -> `OCSF.Ecto.SinkTest`.

---

## 3. Test module structure

### 3.1 Template (DB-backed)

```elixir
defmodule OCSF.Ecto.SinkTest do
  use OCSF.Ecto.DataCase, async: true

  alias OCSF.Ecto.Event, as: EctoEvent
  alias OCSF.Ecto.Sink
  alias OCSF.Events.Authentication

  describe "write/1" do
    test "inserts a single event" do
      event = build_event()
      assert :ok = Sink.write([event])
      assert Repo.aggregate(EctoEvent, :count) == 1
    end
  end

  defp build_event(opts \\ []) do
    default_opts = [user: %{uid: "u1", org: %{uid: "acme"}}]
    {:ok, event} = Authentication.logon(Keyword.merge(default_opts, opts))
    event
  end
end
```

### 3.2 Template (pure / no DB)

```elixir
defmodule OCSF.Ecto.Types.InetTest do
  use ExUnit.Case, async: true

  alias OCSF.Ecto.Types.Inet

  describe "cast/1" do
    test "round-trips a v4 tuple" do
      assert {:ok, {10, 0, 0, 1}} = Inet.cast({10, 0, 0, 1})
    end
  end
end
```

### 3.3 Rules

- **`use OCSF.Ecto.DataCase, async: true`** for tests that call the
  Repo. The case template wires the sandbox, imports `Ecto.Query`,
  and aliases `Repo`.
- **`use ExUnit.Case, async: true`** for pure-function modules that
  don't hit the database (types, pure builders, column helpers).
- **`alias`** frequently used modules at the top (one per line,
  alphabetical). Credo enforces this.
- **`describe` blocks** group tests by function/arity or feature.
  Name them `"function/arity"` or `"feature name"`:

  ```elixir
  describe "write/1" do
  describe "row_for/1" do
  describe "Cloak encryption" do
  describe "policy redaction" do
  ```

- **`test` names** use lowercase, describe the expected behavior,
  not the implementation:

  ```elixir
  # Good
  test "inserts a single event"
  test "user__name and user__email_addr are encrypted at rest"
  test "default policy denies :network"

  # Bad
  test "test_write"
  test "checks the insert_all call returns :ok"
  ```

---

## 4. Sandbox and async rules

### 4.1 How the sandbox works

`test/test_helper.exs` sets `Sandbox.mode(Repo, :manual)`. Each test
module using `OCSF.Ecto.DataCase` gets a sandbox owner in `setup/1`
via `Sandbox.start_owner!(Repo, shared: not tags[:async])` and the
owner is stopped in `on_exit/1`. No manual `Repo.delete_all` needed.

The ownership mode is chosen at `setup/1` time from the `:async`
tag:

- `async: true` — per-test private ownership, each test runs in its
  own transaction, parallel-safe.
- `async: false` — `shared: true` ownership, allowing processes
  spawned by the test to see the same transaction. Tests in the
  module run sequentially.

Mode is not flipped mid-test.

### 4.2 When to go `async: false`

| Shared state touched                         | `async:` | Reason                                                |
|----------------------------------------------|----------|-------------------------------------------------------|
| None / pure                                  | `true`   | Safe to parallelize                                   |
| Only Repo (sandboxed)                        | `true`   | Sandbox isolates per-test transactions                |
| Application config (e.g. `:ocsf_ecto` env)   | `false`  | Global — concurrent tests see mutations               |
| Telemetry handlers                           | `false`  | Global registry — attach/detach races                 |
| Cloak vault cipher config                    | `false`  | Mutates app env, affects all processes                |
| Spawned processes that call the Repo         | `false`  | Sandbox ownership must be `:shared`                   |

Always clean up in `on_exit/1` when mutating shared state:

```elixir
setup do
  previous = Application.get_env(:ocsf_ecto, OCSF.Ecto.Sink, [])
  Application.put_env(:ocsf_ecto, OCSF.Ecto.Sink, policy: custom_policy())

  on_exit(fn ->
    Application.put_env(:ocsf_ecto, OCSF.Ecto.Sink, previous)
  end)

  :ok
end
```

---

## 5. Setup and helpers

### 5.1 `setup` blocks

Use `setup` for shared state within a `describe` block. Return a
map or keyword list for the test context:

```elixir
describe "write/1" do
  setup do
    event = build_event()
    %{event: event}
  end

  test "inserts the event", %{event: event} do
    assert :ok = Sink.write([event])
  end
end
```

### 5.2 Private helpers

Use `defp` for test-local helpers. The `build_event/1` helper in
`sink_test.exs` is the canonical pattern — keyword-override a
sensible default payload:

```elixir
defp build_event(opts \\ []) do
  default_opts = [
    user: %{
      uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
      name: "Jane Doe",
      email_addr: "jane@example.com",
      org: %{uid: "communitiz-app"}
    },
    service: %{name: "Cryptr Auth"},
    status: :Success,
    severity: :Informational,
    auth_protocol: :"OAUTH 2.0"
  ]

  {:ok, event} = Authentication.logon(Keyword.merge(default_opts, opts))
  event
end
```

### 5.3 Shared test helpers

Place reusable helper modules in `test/support/`. They are compiled
via `elixirc_paths(:test)` in `mix.exs`. The sandbox case template
(`OCSF.Ecto.DataCase`) lives here.

### 5.4 Module-based telemetry handlers

**Never use anonymous functions** with `:telemetry.attach/4` in
tests. The telemetry library warns about performance. Always use a
module + function capture:

```elixir
# Good
:telemetry.attach(
  handler_id,
  [:ocsf_ecto, :sink, :write],
  &OCSF.Ecto.TestTelemetryHandler.handle_event/4,
  %{pid: self()}
)

# Bad — triggers telemetry performance warning
:telemetry.attach(
  handler_id,
  [:ocsf_ecto, :sink, :write],
  fn name, m, meta, _ -> send(self(), {:telemetry, name, m, meta}) end,
  nil
)
```

### 5.5 Deterministic doubles

Builders in the core lib call `DateTime.utc_now()` and
`OCSF.UUID.v7_string()`. For sink tests this rarely matters because
we assert on shape, not on timestamps. When timestamps or UIDs
*do* matter (e.g. testing `ON CONFLICT DO NOTHING` idempotency),
override via the core builder's opts:

```elixir
fixed_uid = "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90"

{:ok, event} =
  Authentication.logon(
    user: %{uid: "u1"},
    time: ~U[2026-04-15 10:00:00Z],
    metadata: %{uid: fixed_uid, product: %{name: "Test"}}
  )
```

Don't introduce a clock adapter here — the core lib's opts
overrides are sufficient for this library's test needs.

---

## 6. Assertions

### 6.1 Prefer specific assertions

```elixir
# Good — clear intent, helpful failure message
assert row.class_uid == 3002
assert :ok = Sink.write([event])
assert {:error, %Postgrex.Error{}} = Sink.write(bad_events)

# Bad — opaque failure message
assert row
assert result != nil
```

### 6.2 Pattern match on tagged tuples

```elixir
# Good — extracts and validates in one step
assert {:ok, event} = Authentication.logon(user: %{uid: "u1"})
assert {:down, _reason} = Sink.health()

# Bad — loses the error information
assert {:ok, _} = Authentication.logon(user: %{uid: "u1"})
```

### 6.3 Avoid weak assertions

Credo enforces this. Don't assert on type alone:

```elixir
# Bad — credo warning: weak assertion
assert is_list(rows)
assert is_binary(encrypted_bytes)

# Good — assert something about the value
assert length(rows) == 5
refute String.contains?(encrypted_bytes, "Jane Doe")
```

### 6.4 Non-empty list check

The Elixir type checker warns on `!= []` for lists known to be
non-empty. Credo warns on `length/1 > 0` as expensive. Use pattern
matching:

```elixir
# Good — satisfies both type checker and credo
[_ | _] = rows = Repo.all(EctoEvent)

# Bad — type checker warning (tautological comparison)
assert rows != []

# Bad — credo warning (expensive)
assert length(rows) > 0
```

### 6.5 Assertion count

Keep tests focused. Credo's `TooManyAssertions` check limits to
10 assertions per test. If you need more, split into multiple
tests or use a `for` comprehension:

```elixir
# Acceptable — one logical assertion repeated across data
for {field, expected} <- expected_columns do
  assert Map.get(row, field) == expected
end
```

---

## 7. Test categories

### 7.1 Custom Ecto type unit tests

Test custom Ecto types via `cast/1`, `dump/1`, `load/1` round-trips.
Two sub-cases:

- **Pure types** (`OCSF.Ecto.Types.Inet`) — no Repo, no Vault. Use
  `ExUnit.Case, async: true` directly.
- **Vault-dependent types** (`OCSF.Ecto.Types.EncryptedString`) —
  `dump/1` and `load/1` call into the running `OCSF.Ecto.Vault`
  GenServer, so the OTP app must be started. Use
  `OCSF.Ecto.DataCase, async: true` (the application is up during
  the test run) or `ExUnit.Case, async: true` with an explicit
  `start_supervised!(OCSF.Ecto.Vault)` in `setup`. Either way the
  test is not truly pure — treat ciphertext as opaque and assert
  on round-trip identity, not byte layout.

### 7.2 Sink round-trip tests (DB-backed)

Insert via `Sink.write/1`, read back via `Repo.all/1`, assert on
columns. The canonical test category for this library:

```elixir
test "persists metadata fields" do
  event = build_event()
  :ok = Sink.write([event])

  [row] = Repo.all(EctoEvent)
  assert row.metadata__uid == event.metadata.uid
  assert row.metadata__version == "1.8.0"
end
```

### 7.3 Cloak encryption tests (DB-backed, two-probe)

Every encrypted column needs **two assertions**: one proving the
ciphertext does NOT contain the plaintext (via raw SQL), one proving
Ecto returns the plaintext after a round-trip:

```elixir
test "user__name is encrypted at rest" do
  event = build_event()
  :ok = Sink.write([event])

  {:ok, %{rows: [[bytes]]}} =
    Repo.query("SELECT user__name FROM ocsf_event__logs")

  refute String.contains?(bytes, "Jane Doe")

  [row] = Repo.all(EctoEvent)
  assert row.user__name == "Jane Doe"
end
```

Never trust a single Ecto-layer assertion for encryption — the
type could silently bypass Cloak and the test would still pass.

### 7.4 Policy redaction tests (DB-backed)

Assert that denied `:network` / `:contact` / etc. classes become
`nil` columns after insert:

```elixir
test "default policy denies :network" do
  event = build_event()
  :ok = Sink.write([event])

  [row] = Repo.all(EctoEvent)
  assert row.http_request__url == nil
  assert row.src_endpoint__ip == nil
end
```

### 7.5 Idempotency tests (DB-backed)

Verify `ON CONFLICT DO NOTHING` — writing the same event twice must
leave exactly one row:

```elixir
test "replaying an event is a no-op" do
  event = build_event()
  :ok = Sink.write([event])
  :ok = Sink.write([event])
  assert Repo.aggregate(EctoEvent, :count) == 1
end
```

### 7.6 Property tests (optional)

Use `stream_data` for fuzz-testing custom types:

```elixir
property "Inet round-trips every v4 tuple" do
  check all a <- integer(0..255),
            b <- integer(0..255),
            c <- integer(0..255),
            d <- integer(0..255) do
    assert {:ok, {^a, ^b, ^c, ^d}} = Inet.cast({a, b, c, d})
  end
end
```

---

## 8. Benchmarks

Benchmarks live under `bench/` and are run manually, not in CI:

```bash
mix run bench/sink_bench.exs
mix run bench/sink_bench_populated.exs   # against a 1M-row table
```

Benchmarks use `benchee` (dev-only dep). Don't move them into the
regular test suite — they're too slow and don't assert.

---

## 9. Coverage

- **Threshold**: 90% minimum, 100% target. Enforced by
  `mix test --cover --raise`.
- **Don't game coverage.** A test that calls a function without
  asserting anything is worse than no test.
- **Cover behavior, not lines.** If a private helper (e.g.
  `get_in_safe/2`) is exercised through `Sink.row_for/1`, that's
  sufficient — don't test private functions directly.
- **Coverage gaps are bugs.** If a code path can't be reached by
  tests, question whether the code should exist.

---

## 10. CI expectations

On every PR:

- `mix test --cover --raise` — 0 failures, meets threshold, 0
  warnings. A local Postgres must be running.
- `mix audit` — credo strict, dialyzer, doctor, sobelow, deps
  audit, hex audit all pass.
- `mix format --check-formatted` — no drift.

`mix test` transparently runs `ecto.create --quiet` and
`ecto.migrate --quiet` first (see `mix.exs` aliases).

---

## 11. Recommended libraries

Beyond ExUnit and the deps already in `mix.exs`, these libraries
are recommended when test needs grow.

### Already included

| Library       | Purpose                             | When to use                                     |
|---------------|-------------------------------------|-------------------------------------------------|
| `stream_data` | Property-based / generative testing | Fuzz `Inet`, `EncryptedString`, policy inputs   |
| `benchee`     | Performance benchmarking            | `bench/sink_bench*.exs` — sink throughput       |

### Recommended additions (add when needed)

| Library    | Hex                                         | Purpose                       | When to add                                                                          |
|------------|---------------------------------------------|-------------------------------|--------------------------------------------------------------------------------------|
| `ex_machina` | [hex](https://hex.pm/packages/ex_machina) | Test data factories           | When more than ~3 test modules share `build_event/1`-style helpers.                  |
| `faker`      | [hex](https://hex.pm/packages/faker)      | Realistic fake data           | For property/fixture tests needing realistic names, emails, IPs. Seed for repeatability. |
| `mox`        | [hex](https://hex.pm/packages/mox)        | Behaviour-based mocks         | Only to mock the `OCSF.Sink` behaviour in downstream apps — never the Repo here.     |

### When NOT to add a library

- **Don't mock `OCSF.Ecto.Repo` or Postgrex.** The sandbox gives us
  real behavior at test speed. Mocks silently diverge from
  production (especially for `inet`, encrypted columns, and
  `ON CONFLICT`).
- **Don't add `faker` for round-trip tests** that need stable
  plaintext/ciphertext assertions. Hardcode the values.
- **Don't add `ex_machina` for a single test file.** `defp` helpers
  are lighter. Introduce factories only once duplication is real.

---

## 12. Anti-patterns

- **Mocking the Repo.** We own the sandbox; use it.
- **Asserting only through Ecto on encrypted columns.** Always
  probe the raw bytes via `Repo.query("SELECT ...")` in addition.
- **Test names starting with "test"** — redundant (`test "test
  something"` reads as stuttering).
- **Magic numbers without context** — use module attributes or
  named helpers (`@class_uid 3002` or `build_event()`).
- **Asserting on inspect output** — brittle across Elixir
  versions. Assert on struct fields instead.
- **`sleep`-based synchronization** — use `assert_receive` with
  timeouts for message-based tests.
- **Overly DRY tests** — some repetition is fine if it makes each
  test self-contained and readable. Don't abstract away the setup
  to the point where reading a test requires jumping to three
  helper modules.

---

## 13. Checklist

Before merging, verify:

- [ ] Every new public function has at least one test.
- [ ] `mix test --cover --raise` passes with 0 warnings.
- [ ] `mix audit` passes (credo, dialyzer, doctor, sobelow, deps).
- [ ] `mix format --check-formatted` passes.
- [ ] Test names describe behavior, not implementation.
- [ ] No `async: false` without a documented reason.
- [ ] No anonymous functions in telemetry handlers.
- [ ] No mocks of Repo or Postgrex — sandbox only.
- [ ] Every encrypted column has the two-probe test (raw bytes +
      Ecto round-trip).
- [ ] Shared app config mutations are cleaned up in `on_exit/1`.
