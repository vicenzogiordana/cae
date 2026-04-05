# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :cae,
  ecto_repos: [Cae.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :cae, CaeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CaeWeb.ErrorHTML, json: CaeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Cae.PubSub,
  live_view: [signing_salt: "CJ9GsVfs"]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  cae: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Cloak for encrypting sensitive medical data
config :cae, Cae.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("tnDKk8h+O5MzE8F/9qV6z9N0L7u5W2p8Q3k1j4M6x9B5A2c="),
      iv_length: 12
    }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
