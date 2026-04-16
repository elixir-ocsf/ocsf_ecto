import Config

# Runtime configuration for production.
# Consumers override these via env vars.

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :ocsf_ecto, OCSF.Ecto.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("DATABASE_SSL") == "true"

  # Production vault key — MUST be provided by consumer
  cloak_key =
    System.get_env("CLOAK_KEY") ||
      raise """
      environment variable CLOAK_KEY is missing.
      Generate with: :crypto.strong_rand_bytes(32) |> Base.encode64()
      """

  config :ocsf_ecto, OCSF.Ecto.Vault,
    ciphers: [
      default:
        {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(cloak_key), iv_length: 12}
    ]
end
