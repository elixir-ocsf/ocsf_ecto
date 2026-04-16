defmodule OCSF.Ecto do
  @moduledoc """
  Postgres Ecto companion library for the core `OCSF` library.

  Provides an `OCSF.Sink` implementation backed by Postgres, with
  Cloak field-level encryption for PII attributes and policy-driven
  redaction before insert. Events are stored in the single flat
  table `ocsf_event__logs` — nested OCSF paths are projected to
  columns using the `__` segment separator (e.g. `user.email_addr`
  becomes `user__email_addr`).

  Corresponds to persistence for the OCSF
  [Base Event](https://schema.ocsf.io/1.8.0/classes/base_event) and
  its embedded objects.

  ## Module map

  | Module                              | Role                                          |
  |-------------------------------------|-----------------------------------------------|
  | `OCSF.Ecto.Sink`                    | `OCSF.Sink` implementation — write path       |
  | `OCSF.Ecto.Event`                   | Ecto schema for `ocsf_event__logs`            |
  | `OCSF.Ecto.Repo`                    | Postgres `Ecto.Repo`                          |
  | `OCSF.Ecto.Vault`                   | Cloak vault (AES-GCM) for PII columns         |
  | `OCSF.Ecto.Types.EncryptedString`   | Cloak-backed Ecto type for `:contact` PII     |
  | `OCSF.Ecto.Types.Inet`              | Ecto type mapping Postgres `inet` <-> tuples  |
  """
end
