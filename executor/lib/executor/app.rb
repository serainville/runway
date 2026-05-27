# frozen_string_literal: true

require "json"
require "rack"

require_relative "../../config/routes"
require_relative "command_server"

module Executor
  class App
    def self.build
      Rack::Builder.new do
        use Rack::ContentLength
        run Executor::CommandServer.new
      end
    end
  end
end
