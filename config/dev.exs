import Config

config :ocsf_ecto, OCSF.Ecto.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  database: "ocsf_ecto_dev",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true,
  stacktrace: true
