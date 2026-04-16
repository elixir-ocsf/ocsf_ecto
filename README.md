# ocsf_ecto

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Postgres companion for the [`ocsf`](https://hex.pm/packages/ocsf)
Elixir library. Provides an `OCSF.Sink` implementation backed by
`Ecto` + `postgrex`, with [Cloak](https://hex.pm/packages/cloak_ecto)
field-level encryption for PII attributes (`:contact`, `:identity`
data classes) and policy-driven redaction applied before insert.

- **Single flat table** — `ocsf_event__logs`, with nested OCSF
  paths projected via the `__` segment separator
  (e.g. `user.email_addr` → `user__email_addr`).
- **Encryption at rest** — PII columns encrypted via AES-GCM
  through `OCSF.Ecto.Types.EncryptedString`.
- **Idempotent writes** — primary key is the event's
  `metadata.uid`, so replaying the same event is a no-op.
- **Policy-driven redaction** — denied data classes become `nil`
  columns before insert.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:ocsf, "~> 0.1"},
    {:ocsf_ecto, "~> 0.1"}
  ]
end
```

## Configuration

```elixir
# config/config.exs
config :ocsf_ecto, OCSF.Ecto.Repo,
  database: "my_app_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :ocsf_ecto, ecto_repos: [OCSF.Ecto.Repo]

# Cloak vault — generate a key with:
#   :crypto.strong_rand_bytes(32) |> Base.encode64()
# The production key MUST come from the environment.
config :ocsf_ecto, OCSF.Ecto.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key: Base.decode64!(System.get_env("CLOAK_KEY") || raise "CLOAK_KEY not set"),
       iv_length: 12}
  ]
```

### Running inside a host app with its own Repo

`OCSF.Ecto.Application` starts `OCSF.Ecto.Repo` under its own
supervision tree by default. If your host app already owns a Repo
(or runs migrations separately), disable the library's Repo boot:

```elixir
config :ocsf_ecto, OCSF.Ecto.Repo, start: false
```

and supervise `OCSF.Ecto.Repo` from your own tree.

## Schema setup

The library ships a single migration at
`priv/repo/migrations/*_create_ocsf_event_logs.exs`. Copy it into
your app (or run against this Repo directly):

```bash
mix ecto.create
mix ecto.migrate
```

See `priv/repo/migrations/` for the full DDL. Every column follows
the `__` flat-projection naming; nullability mirrors OCSF 1.8
required fields.

## Writing events

```elixir
# Build an event via the core lib
{:ok, event} =
  OCSF.Events.Authentication.logon(
    user: %{uid: "u1", org: %{uid: "acme"}},
    service: %{name: "My Auth"},
    status: :Success,
    severity: :Informational,
    auth_protocol: :"OAUTH 2.0"
  )

# Write via the Postgres sink (applies policy + encrypts PII)
:ok = OCSF.Ecto.Sink.write([event])

# Replays are idempotent on metadata.uid
:ok = OCSF.Ecto.Sink.write([event])
```

Batch writes use a single `insert_all/3`:

```elixir
:ok = OCSF.Ecto.Sink.write(many_events)
```

## Policy

The sink runs `OCSF.Policy.apply/2` on every event before insert.
Denied data classes become `nil` in the row; allowed classes pass
through (and PII classes are Cloak-encrypted at the column level).

Default policy:

```elixir
%OCSF.Policy{
  allow: [:identifier, :tenant, :taxonomic, :temporal, :contact, :identity],
  deny:  [:network],
  transform: []
}
```

Override per-sink via application config:

```elixir
config :ocsf_ecto, OCSF.Ecto.Sink,
  policy: %OCSF.Policy{
    allow: [:identifier, :tenant, :taxonomic, :temporal],
    deny:  [:contact, :identity, :network],
    transform: []
  }
```

## Reading events

The library focuses on the **write path**. For reads, query
`OCSF.Ecto.Event` directly via your own Repo code — Cloak columns
decrypt transparently when loaded through the schema:

```elixir
import Ecto.Query

OCSF.Ecto.Event
|> where([e], e.class_uid == 3002)
|> order_by([e], desc: e.time)
|> limit(100)
|> OCSF.Ecto.Repo.all()
```

## Health check

```elixir
case OCSF.Ecto.Sink.health() do
  :ok -> :healthy
  {:down, reason} -> {:unhealthy, reason}
end
```

## Security notes

- **Key management:** `CLOAK_KEY` must be provisioned out-of-band
  in production (env var, secret manager). Never commit keys.
- **Key rotation:** follow the Cloak
  [migration guide](https://hexdocs.pm/cloak_ecto/generate_migrate_encrypted_data.html).
  Multiple ciphers can be configured with `default:` pointing at the
  current key; old ciphertext stays readable while new writes use
  the new key.
- **Raw-bytes assertion:** every encrypted column is tested with a
  raw-SQL probe that proves the plaintext is not present in the
  column (see `test/ocsf/ecto/event_test.exs`).

## Links

- [`ocsf`](https://hex.pm/packages/ocsf) — core library
- [OCSF 1.8 Schema](https://schema.ocsf.io/1.8.0/)
- [Cloak](https://hex.pm/packages/cloak_ecto) — field-level encryption
- [Ecto](https://hex.pm/packages/ecto_sql) — persistence layer

## License

Apache-2.0
