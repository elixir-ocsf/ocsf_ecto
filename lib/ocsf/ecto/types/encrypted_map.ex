defmodule OCSF.Ecto.Types.EncryptedMap do
  @moduledoc """
  Cloak-encrypted JSON type for PII-bearing OCSF sub-objects.

  Wraps `Cloak.Ecto.Map` with the default cipher from
  `OCSF.Ecto.Vault`: the value is JSON-encoded then encrypted, and the
  ciphertext is stored in a `:binary` column. Used for the sub-objects
  that carry name/email — `actor`, `updated_user`, `entity` — so that
  PII never lands in a plain `jsonb` column at rest.

  Read back transparently as a map by `OCSF.Ecto.Event.to_ocsf_map/1`.
  """

  use Cloak.Ecto.Map, vault: OCSF.Ecto.Vault
end
