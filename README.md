# ocsf_ecto

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Postgres Ecto adapter for the [`ocsf`](https://hex.pm/packages/ocsf)
Elixir library. Provides an `OCSF.Sink` implementation backed by
Postgres, with Cloak field-level encryption for PII attributes.

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
config :my_app, OCSF.Ecto.Repo,
  database: "my_app_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :ocsf_ecto,
  ecto_repos: [OCSF.Ecto.Repo]

# Cloak vault — production key MUST be provided via CLOAK_KEY env var
config :ocsf_ecto, OCSF.Ecto.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key: Base.decode64!(System.get_env("CLOAK_KEY")),
       iv_length: 12}
  ]
```

Generate a production key:

```elixir
:crypto.strong_rand_bytes(32) |> Base.encode64()
```

## Usage

```elixir
# Build an OCSF event via the core lib
{:ok, event} =
  OCSF.Events.Authentication.logon(
    user: %{uid: "u1", org: %{uid: "acme"}},
    service: %{name: "My Auth"},
    status: :Success,
    severity: :Informational,
    auth_protocol: :"OAUTH 2.0"
  )

# Write to Postgres via the sink
OCSF.Ecto.Sink.write([event])
#=> :ok
```

## Features

- **Single-table** `ocsf_event__logs` with flat `__` column projection
- **Field-level encryption** via Cloak on `user__name`, `user__email_addr`
- **Policy-driven redaction** — denied data classes nilled before insert
- **Sink health check** via `OCSF.Ecto.Sink.health/0`
- **Configurable policy** per-sink via application config

## Schema

The migration creates `ocsf_event__logs` with columns for every
supported OCSF attribute flattened via the `__` naming convention.
See `priv/repo/migrations/` for the DDL.

## Links

- [`ocsf`](https://hex.pm/packages/ocsf) — core library
- [Cloak](https://hex.pm/packages/cloak_ecto) — field-level encryption
- [OCSF 1.8 Schema](https://schema.ocsf.io/1.8.0/)

## License

Apache-2.0
