import Config

config :legion,
  model: "openai:gpt-4o-mini",
  timeout: 30_000,
  max_iterations: 10,
  max_retries: 3,
  sandbox: [
    timeout: 5_000
  ]

import_config "#{config_env()}.exs"
