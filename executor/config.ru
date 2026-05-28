# frozen_string_literal: true

require_relative "lib/executor/env_loader"
Executor::EnvLoader.load!

require_relative "lib/executor/app"

run Executor::App.build
