# ocsf_ecto — Claude Code Instructions

## Project overview

Postgres companion library for the
[`ocsf`](../ocsf) core Elixir library. Provides an `OCSF.Sink`
implementation backed by Postgres/Ecto, with Cloak field-level
encryption for PII attributes (`:contact`, `:identity`) and
policy-driven redaction before insert.

Single table: `ocsf_event__logs`. Flat column projection using
`__` as the nested-segment separator (e.g. `user__email_addr`,
`metadata__product__name`).

## Before starting any task

1. Read the planning docs in `../.agents/`:
   - `PLAN.md` — architecture, decisions, milestones (this lib = M2)
   - `SPEC.md` — concrete APIs, struct shapes, DDL, validation
   - `QA.md` — QA strategy and per-milestone gates
   - `EVENT_CODE_FORMAT_CONFIG_SPEC.md` — event code generation
2. Check the current milestone status in `PLAN.md` §Milestones.
   `ocsf_ecto` is the M2 deliverable.
3. Read `DOC_GUIDELINES.md` and `TESTING_GUIDELINES.md` before
   writing any code.

## After every code change

Always run this sequence before committing:

```bash
mix format
mix test --cover --raise    # 0 failures, 0 warnings, coverage >= 90%
mix audit                   # credo, dialyzer, doctor, sobelow, deps.audit, hex.audit
```

`mix test` automatically runs `ecto.create --quiet` and
`ecto.migrate --quiet` first (see `mix.exs` aliases), so you need
a running Postgres instance on `localhost`.

Fix all issues before committing. Never commit with warnings,
failing tests, or audit failures.

## Git conventions

- Start every commit message with an emoji.
- Never add `Co-Authored-By: Claude` lines.
- Use `git add -A` before committing.
- Write concise commit messages explaining the "why".

## Code conventions

- Follow `DOC_GUIDELINES.md` for all documentation:
  - Every public module has `@moduledoc`.
  - Every public function has `@doc` with `## Examples` and `@spec`.
  - OCSF schema link on every module that maps to an OCSF concept.
  - No duplicate examples between `@moduledoc` and `@doc`.

- Follow `TESTING_GUIDELINES.md` for all tests:
  - `use OCSF.Ecto.DataCase, async: true` for DB-backed tests.
  - Sandbox handles cleanup — no manual `Repo.delete_all`.
  - Module-based telemetry handlers, never anonymous functions.
  - Non-empty list check: `[_ | _] = list`, not `!= []` or `length > 0`.
  - Pattern-match on tagged tuples in assertions.

## OCSF field naming (persistence layer)

- `__` (double underscore) is the flat-projection segment separator
  everywhere: table names, column names, index names.
- Default table: `ocsf_event__logs` (prefix `ocsf_event__`, base `logs`).
- Nested-field columns use the full dotted path joined by `__`:
  - `metadata.product.name` -> `metadata__product__name`
  - `user.org.uid`          -> `user__org__uid`
  - `src_endpoint.ip`       -> `src_endpoint__ip`
- Enum suffixes come from the core lib: `_id` for enum values
  (`activity_id`, `severity_id`), `_uid` for unique identifiers
  (`class_uid`, `type_uid`, `metadata__uid`).

## Key architectural decisions

- Runtime deps: `:ocsf` (path `../ocsf`), `:ecto_sql`, `:postgrex`,
  `:cloak_ecto`, `:jason`.
- Test/dev only: `stream_data`, `benchee`, `ex_doc`, `credo`,
  `dialyxir`, `doctor`, `sobelow`, `mix_audit`, `mix_test_watch`.
- Cloak vault `OCSF.Ecto.Vault` reads `CLOAK_KEY` from env at boot;
  tests use a fixed base64 key from `config/test.exs`.
- Encrypted columns use `OCSF.Ecto.Types.EncryptedString`
  (Cloak-backed Ecto type). PII fields are `user__name` and
  `user__email_addr` by default.
- IP columns use `OCSF.Ecto.Types.Inet` (Postgres `inet` <-> Erlang
  tuple). `nil`-safe — denied `:network` fields round-trip as `nil`.
- Primary key is `:id` (binary_id) seeded from `metadata.uid` so
  the OCSF event UID is the row UID.
- `on_conflict: :nothing, conflict_target: :id` — idempotent writes.
- Redaction is applied by `OCSF.Policy.apply/2` **inside** the sink,
  before the row map is built. Denied classes become `nil` columns.
- Default policy: `allow: [:identifier, :tenant, :taxonomic,
  :temporal, :contact, :identity]`, `deny: [:network]`.
- Supervision: `OCSF.Ecto.Application` starts `OCSF.Ecto.Repo` and
  `OCSF.Ecto.Vault`. Hosts with their own Repo should set
  `config :ocsf_ecto, OCSF.Ecto.Repo, start: false` (see `README`).

## What NOT to do

- Don't add features beyond the current milestone scope (M2 = sink
  + schema + migration + Cloak; pipeline/batching/fan-out is M4+).
- Don't skip `mix audit` — it catches real issues (credo strict,
  dialyzer, sobelow, dep audits).
- Don't use anonymous functions in `:telemetry.attach/4`.
- Don't mock `OCSF.Ecto.Repo` — tests run against a real Postgres
  via the sandbox. Mocks diverge from production behavior.
- Don't commit `erl_crash.dump`, `_build/`, `deps/`, `cover/`.
- Don't add new encrypted fields without also adding a round-trip
  test that asserts (a) plaintext is returned via Ecto and (b) the
  raw bytes in the column do NOT contain the plaintext.
