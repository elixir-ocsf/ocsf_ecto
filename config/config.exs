import Config

config :ocsf_ecto,
  ecto_repos: [OCSF.Ecto.Repo]

config :ocsf_ecto, OCSF.Ecto.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]

# Cloak vault — consumers MUST override the key in their own config.
# The key below is a placeholder for dev/test.
config :ocsf_ecto, OCSF.Ecto.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key: Base.decode64!("rCGLsiEb4a+SzrOmBB/0cFz24t2/A1XyOfrd3MTl/tI="),
       iv_length: 12}
  ]

import_config "#{config_env()}.exs"
