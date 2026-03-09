import Config

if config_env() == :test do
  # This is needed for `Jason` source code to be stored during the compilation
  config :legion, :extra_source_modules, [Jason]
end
