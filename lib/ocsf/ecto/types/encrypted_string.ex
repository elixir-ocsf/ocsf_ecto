defmodule OCSF.Ecto.Types.EncryptedString do
  @moduledoc """
  Cloak-encrypted string type for PII fields (`:contact`, `:identity`).

  Wraps `Cloak.Ecto.Binary` with the default cipher from
  `OCSF.Ecto.Vault`. Used on `user__name` and `user__email_addr`
  columns in `OCSF.Ecto.Event`.
  """

  use Cloak.Ecto.Binary, vault: OCSF.Ecto.Vault
end
