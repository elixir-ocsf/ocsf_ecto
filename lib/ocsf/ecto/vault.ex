defmodule OCSF.Ecto.Vault do
  @moduledoc """
  Cloak vault for field-level encryption.

  Encrypts PII fields (`:contact` and `:identity` data classes) at
  rest in Postgres using AES-GCM. Keys are configured via
  `config :ocsf_ecto, OCSF.Ecto.Vault, ciphers: [...]`.

  Consumers MUST override the default cipher key in production via
  the `CLOAK_KEY` environment variable (see `config/runtime.exs`).

  Generate a production key with:

      :crypto.strong_rand_bytes(32) |> Base.encode64()

  See `OCSF.Ecto.Types.EncryptedString` for the PII field type.
  """

  use Cloak.Vault, otp_app: :ocsf_ecto
end
