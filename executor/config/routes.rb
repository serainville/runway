# frozen_string_literal: true

module Executor
  module Routes
    HEALTH_PATH = "/healthz"
    READY_PATH = "/readyz"
    BUILD_COMMANDS_PATH = "/v1/build-commands"
    BUILD_COMMAND_LOOKUP_PATTERN = %r{\A/v1/build-commands/(?<command_id>[A-Za-z0-9_-]+)\z}
  end
end
