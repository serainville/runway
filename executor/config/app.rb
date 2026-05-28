# frozen_string_literal: true

module Executor
  module Config
    module_function

    def backend_mode
      ENV.fetch("EXECUTOR_BACKEND_MODE", "docker")
    end

    def signing_key_id
      ENV.fetch("EXECUTOR_SIGNING_KEY_ID")
    end

    def signing_secret
      ENV.fetch("EXECUTOR_SIGNING_SECRET")
    end

    def callback_base_url
      ENV.fetch("RUNWAY_CALLBACK_BASE_URL")
    end

    def callback_timeout_seconds
      Integer(ENV.fetch("RUNWAY_CALLBACK_TIMEOUT_SECONDS", "10"), 10)
    end

    def callback_signing_key_id
      ENV.fetch("EXECUTOR_CALLBACK_SIGNING_KEY_ID", signing_key_id)
    end

    def callback_signing_secret
      ENV.fetch("EXECUTOR_CALLBACK_SIGNING_SECRET", signing_secret)
    end

    def heartbeat_enabled?
      ENV.fetch("EXECUTOR_HEARTBEAT_ENABLED", "true") == "true"
    end

    def heartbeat_interval_seconds
      Integer(ENV.fetch("EXECUTOR_HEARTBEAT_INTERVAL_SECONDS", "30"), 10)
    end

    def bind_address
      ENV.fetch("EXECUTOR_BIND_ADDRESS", "0.0.0.0")
    end

    def port
      Integer(ENV.fetch("EXECUTOR_PORT", "4100"), 10)
    end

    def registration_name
      ENV["EXECUTOR_REGISTRATION_NAME"].to_s
    end

    def registration_endpoint
      configured = ENV["EXECUTOR_REGISTRATION_ENDPOINT"].to_s
      return configured unless configured.empty?

      host = bind_address == "0.0.0.0" ? "127.0.0.1" : bind_address
      "http://#{host}:#{port}"
    end

    def docker_local_commands_enabled?
      ENV.fetch("EXECUTOR_ENABLE_DOCKER_LOCAL_COMMANDS", "false") == "true"
    end

    def docker_default_timeout_seconds
      Integer(ENV.fetch("EXECUTOR_DOCKER_DEFAULT_TIMEOUT_SECONDS", "900"), 10)
    end

    def docker_workdir
      ENV.fetch("EXECUTOR_DOCKER_WORKDIR", Dir.pwd)
    end

    def keep_workspace?
      ENV.fetch("EXECUTOR_KEEP_WORKSPACE", "false") == "true"
    end
  end
end
