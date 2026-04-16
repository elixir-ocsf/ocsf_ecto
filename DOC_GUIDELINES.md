# Documentation Guidelines

Documentation style for the `ocsf_ecto` library, inspired by
[Ecto](https://github.com/elixir-ecto/ecto)'s documentation patterns.

---

## 1. Principles

- **Documentation is part of the API.** Every public module and function
  must have `@moduledoc` / `@doc`. Doctor enforces 100% coverage.
- **Teach, don't just describe.** Explain *why* something exists, not
  just *what* it does. A reader coming from the OCSF spec or from
  Ecto should understand how persistence is structured here.
- **Progressive disclosure.** Start with the simplest usage, then layer
  complexity. First paragraph answers "what does this do?", examples
  answer "how do I use it?", sections answer "what are the edge cases?".
- **One source of truth.** Don't duplicate information across modules.
  Cross-reference with backtick links instead.

---

## 2. Module documentation (`@moduledoc`)

### 2.1 Structure

Every `@moduledoc` follows this order:

1. **Opening summary** — one paragraph, plain language, no jargon.
   Answers: "What is this module and when do I use it?"
2. **Example** — a short, *unique* code snippet that shows the module
   in context (e.g. how a sink call fits in an event-ingest pipeline).
   This is NOT a doctest — it demonstrates the "why", not the API
   surface. Appears before any deep-dive sections.
3. **Sections** — `##` headings for distinct topics (options, types,
   edge cases, OCSF mapping, configuration, etc.).
4. **Cross-references** — links to related modules at the end, not
   scattered throughout.

### 2.1.1 No-duplication rule

> **Module examples must not repeat function examples.**
> `@moduledoc` examples show the module *in context* — how it
> connects to other modules or fits in a workflow. `@doc` examples
> show the *individual function's* inputs and outputs. If a doctest
> on `Sink.write/1` says `OCSF.Ecto.Sink.write([event]) => :ok`, the
> `@moduledoc` must NOT repeat that same call. Instead, the module
> example shows a *usage scenario*:

```elixir
# Good @moduledoc example (contextual, not a function repeat):
@moduledoc """
...
## Example

    # Build via the core lib, persist via the sink:
    {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
    :ok = OCSF.Ecto.Sink.write([event])
...
"""

# Bad @moduledoc example (duplicates the @doc on write/1):
@moduledoc """
...
## Examples

    iex> OCSF.Ecto.Sink.write([])
    :ok
...
"""
```

When the module has only one or two functions and a contextual
example would be forced, **omit the `## Example` section from
`@moduledoc` entirely** — the function doctests are sufficient.

### 2.2 Opening summary examples

Good:

```elixir
@moduledoc """
Postgres sink implementation of the `OCSF.Sink` behaviour.

Writes `%OCSF.Event{}` structs to the `ocsf_event__logs` table via
`Ecto.Repo.insert_all/3`. Applies the configured `OCSF.Policy` for
field-level redaction before insert. PII columns are transparently
encrypted via Cloak.
"""
```

Bad:

```elixir
@moduledoc """
This module provides sink functionality.
"""
```

### 2.3 Sections

Use `##` for top-level sections inside `@moduledoc`:

```elixir
@moduledoc """
...opening summary...

## OCSF mapping

This schema is the flat projection of the OCSF
[Authentication](https://schema.ocsf.io/1.8.0/classes/authentication)
class and its embedded objects. See SPEC §6 for the naming
convention.

## Columns

Columns follow the `__` flat-projection convention: every nested
field path in the canonical struct becomes a single column with
segments joined by `__`:

| OCSF path                 | Column                      |
|---------------------------|-----------------------------|
| `metadata.uid`            | `metadata__uid`             |
| `metadata.product.name`   | `metadata__product__name`   |
| `user.org.uid`            | `user__org__uid`            |
| `src_endpoint.ip`         | `src_endpoint__ip`          |

## Example

    {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
    :ok = OCSF.Ecto.Sink.write([event])
"""
```

### 2.4 Callouts

Use `>` blockquotes with a bold title for important notes:

```elixir
@moduledoc """
...

> **Security note:** `CLOAK_KEY` must be provided via the environment
> in production. Rotating the key requires the migration strategy
> documented in `OCSF.Ecto.Vault`.
"""
```

For info-level callouts (non-critical):

```elixir
> **Note:** Writes are idempotent via `ON CONFLICT DO NOTHING` on
> the `:id` column. Replaying the same event is a no-op.
```

---

## 3. Function documentation (`@doc`)

### 3.1 Structure

1. **First sentence** — what the function does, in imperative mood.
   This sentence appears in the function list on HexDocs.
2. **Details** — additional context, constraints, behavior on `nil`
   or edge cases. Keep it short.
3. **`## Options`** — if the function accepts a keyword list, document
   each key with type and default.
4. **`## Examples`** — at least one, using `iex>` for doctests or
   indented code blocks for non-doctest examples (DB-backed calls
   should never be doctests).

### 3.2 Example

```elixir
@doc """
Builds the raw row map for a `%OCSF.Event{}`.

Applies the sink's policy, encrypts PII via Cloak, and returns the
map passed to `Ecto.Repo.insert_all/3`. Exposed for diagnostic and
test use.

## Examples

    {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
    row = OCSF.Ecto.Sink.row_for(event)
    row.class_uid
    #=> 3002
"""
@spec row_for(OCSF.Event.t()) :: map
def row_for(%OCSF.Event{} = event) do
```

### 3.3 Options sections

Use a definition list (bullet + bold key):

```elixir
@doc """
Writes events to the Postgres sink.

## Options

Behaviour is configured via `Application.get_env/2` rather than opts:

- **`:policy`** — `%OCSF.Policy{}` applied before insert. Defaults
  to `allow: [:identifier, :tenant, :taxonomic, :temporal, :contact,
  :identity], deny: [:network]`.

## Examples

    :ok = OCSF.Ecto.Sink.write([event])
"""
```

---

## 4. Code examples

### 4.1 Doctests (`iex>`)

Use for pure functions with small, predictable output — typically
helpers that don't touch the Repo or the Vault. A real example
from `OCSF.Ecto.Types.Inet`:

```elixir
@doc """
Casts an Erlang IP tuple to the internal representation.

## Examples

    iex> OCSF.Ecto.Types.Inet.cast({10, 0, 0, 1})
    {:ok, {10, 0, 0, 1}}

    iex> OCSF.Ecto.Types.Inet.cast(nil)
    {:ok, nil}
"""
```

For doctests to actually run, the corresponding test module must
include `doctest OCSF.Ecto.Types.Inet`.

### 4.2 Indented code blocks (DB-backed calls)

Use for examples that produce complex output, touch the database,
or would make poor doctests:

```elixir
@doc """
...

## Examples

    {:ok, event} = OCSF.Events.Authentication.logon(user: %{uid: "u1"})
    :ok = OCSF.Ecto.Sink.write([event])

    OCSF.Ecto.Repo.aggregate(OCSF.Ecto.Event, :count)
    #=> 1
"""
```

Use `#=>` for inline expected-output comments (not `#`).

**Never put DB-backed calls inside `iex>` doctest syntax** — doctests
run without the sandbox and would hit a real transaction.

### 4.3 Progression

Show the simple case first, then edge cases:

```elixir
## Examples

    # Single event
    :ok = OCSF.Ecto.Sink.write([event])

    # Batch of events
    :ok = OCSF.Ecto.Sink.write(many_events)

    # Replay is a no-op (idempotent on metadata.uid)
    :ok = OCSF.Ecto.Sink.write([event])
```

---

## 5. Cross-references

### 5.1 Module links

Use backtick-wrapped module names. HexDocs auto-links them:

```elixir
See `OCSF.Ecto.Event` for the Ecto schema backing the sink.
```

### 5.2 Function links

Use `module.function/arity` form:

```elixir
Delegates redaction to `OCSF.Policy.apply/2`.
```

### 5.3 External links

Link to the OCSF schema for every module that maps to an OCSF
concept, and to Ecto/Cloak for third-party types:

```elixir
Corresponds to the OCSF
[Authentication](https://schema.ocsf.io/1.8.0/classes/authentication)
class (UID 3002).

Wraps `Cloak.Ecto.Binary` — see the
[Cloak docs](https://hexdocs.pm/cloak_ecto).
```

### 5.4 SPEC cross-references

Reference the SPEC by section number when documenting design
decisions (the SPEC lives at `../.agents/SPEC.md`):

```elixir
> The flat-projection naming convention is defined in SPEC §6.
> Nested OCSF paths are joined with `__` across table, column,
> and index names.
```

---

## 6. Typespecs

- Every public function has `@spec`.
- Use custom `@type` definitions on structs, including the Ecto
  schema itself (`@type t :: %__MODULE__{}`).
- Prefer named types over inline unions for readability:

```elixir
@type write_result :: :ok | {:error, Exception.t() | term}
```

---

## 7. Ecto schema modules

Every Ecto schema module follows this template:

```elixir
defmodule OCSF.Ecto.Event do
  @moduledoc """
  Ecto schema for the `ocsf_event__logs` Postgres table.

  Flat projection of `%OCSF.Event{}` using the `__` naming
  convention (SPEC §6). PII columns use
  `OCSF.Ecto.Types.EncryptedString` (Cloak-backed). See
  `OCSF.Ecto.Sink` for the write path and
  [OCSF Event](https://schema.ocsf.io/1.8.0/classes/base_event)
  for the canonical nested shape.

  ## Encrypted columns

  - `user__name` (`:contact` / `:identity`)
  - `user__email_addr` (`:contact` / `:identity`)

  ## Primary key

  `:id` (`:binary_id`) is seeded from `metadata.uid` so the OCSF
  event UID is the row UID — enabling `ON CONFLICT DO NOTHING`
  idempotency.
  """

  use Ecto.Schema
  @type t :: %__MODULE__{}
  # schema "..." do ... end
end
```

Do **not** use `@doc false` to hide fields — document encrypted
columns in a `## Encrypted columns` section and type columns
(`Inet`, `EncryptedString`) in `## Custom types`.

---

## 8. Ecto.Type shim modules

Every custom Ecto type follows this template:

```elixir
defmodule OCSF.Ecto.Types.Inet do
  @moduledoc """
  Ecto type mapping the Postgres `inet` column to Erlang IP tuples.

  Nil-safe — `nil` in, `nil` out — so denied `:network` fields
  round-trip cleanly after policy redaction.

  ## Examples

      iex> OCSF.Ecto.Types.Inet.cast({10, 0, 0, 1})
      {:ok, {10, 0, 0, 1}}

      iex> OCSF.Ecto.Types.Inet.cast(nil)
      {:ok, nil}
  """

  use Ecto.Type
  # ...
end
```

---

## 9. Migration modules

Migrations are documented inline via short module-level comments,
not `@moduledoc` (migrations aren't part of the public API and are
not required to pass doctor). Keep comments focused on *why* a
constraint or index exists, not what the DDL does.

```elixir
defmodule OCSF.Ecto.Repo.Migrations.CreateOcsfEventLogs do
  # Creates the single ocsf_event__logs table. One table per OCSF
  # class is intentionally avoided for v0 — class-specific sharding
  # is deferred to v1 (see PLAN.md §Persistence design).
  use Ecto.Migration

  def change do
    # ...
  end
end
```

---

## 10. Naming conventions in docs

- Use **OCSF field names** in prose (`activity_id`, not "activity
  identifier" or "activity UID").
- Use **backticks** for code references: `` `severity_id` ``,
  `` `OCSF.Ecto.Sink` ``, `` `write/1` ``.
- Use **bold** for emphasis on terms defined in the Glossary:
  **sink**, **policy**, **redaction**, **data class**, **vault**.
- Use the `__` flat-column form when discussing persistence:
  `` `user__email_addr` ``, not "user.email_addr column".
- Say "OCSF 1.8" not "the OCSF standard" when the version matters.
- Say "Postgres" not "PostgreSQL" in prose (adapter docs are the
  exception).

---

## 11. What NOT to document

- Implementation details that may change (internal data structures,
  private function behavior).
- Information derivable from typespecs alone (don't restate the
  spec in prose if the types are self-explanatory).
- Git history or changelog entries in module docs.
- Planned/future features — document what exists now.
- Migration DDL mechanics (readers can read the file).

---

## 12. Checklist

Before merging, verify:

- [ ] Every public module has `@moduledoc`.
- [ ] Every public function has `@doc` and `@spec`.
- [ ] At least one example per public function.
- [ ] OCSF schema link in every module that maps to an OCSF
      concept; Cloak/Ecto link in every type/schema module.
- [ ] Cross-references use backtick module/function syntax.
- [ ] No doctest touches the Repo or the Vault.
- [ ] `mix doctor --raise` passes (100% doc + spec coverage).
- [ ] No `TODO` or `FIXME` in docs (use issues instead).
