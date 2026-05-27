# frozen_string_literal: true

require "json"
require "json_schemer"

module Executor
  module Callbacks
    class CallbackValidator
      def initialize(schema_path: default_schema_path)
        @schema_path = schema_path
        @schemer = JSONSchemer.schema(JSON.parse(File.read(schema_path)))
      end

      def call(payload)
        errors = schemer.validate(payload).map do |error|
          {
            path: error.fetch("data_pointer", "/"),
            message: error.fetch("type", "schema_error")
          }
        end

        {
          ok: errors.empty?,
          errors: errors
        }
      end

      private

      attr_reader :schema_path, :schemer

      def default_schema_path
        runway_root = File.expand_path("../../../..", __dir__)
        File.expand_path("docs/executor/contracts/build-callback.schema.json", runway_root)
      end
    end
  end
end
