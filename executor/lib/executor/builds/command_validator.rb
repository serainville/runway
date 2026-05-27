# frozen_string_literal: true

require "json"
require "json_schemer"

module Executor
  module Builds
    class CommandValidator
      EXPECTED_STEP_ORDER = %w[lint test build].freeze

      def initialize(schema_path: default_schema_path)
        @schema_path = schema_path
        @schemer = JSONSchemer.schema(JSON.parse(File.read(schema_path)))
      end

      def call(payload)
        errors = schemer.validate(payload).map { |error| format_schema_error(error) }
        errors.concat(validate_step_order(payload))

        {
          ok: errors.empty?,
          errors: errors
        }
      end

      private

      attr_reader :schema_path, :schemer

      def default_schema_path
        runway_root = File.expand_path("../../../..", __dir__)
        File.expand_path("docs/executor/contracts/build-command.schema.json", runway_root)
      end

      def validate_step_order(payload)
        return [] unless payload.is_a?(Hash) && payload["steps"].is_a?(Array)

        names = payload["steps"].filter_map { |step| step.is_a?(Hash) ? step["name"] : nil }
        return [] if names == EXPECTED_STEP_ORDER

        [
          {
            path: "/steps",
            message: "must be ordered as lint, test, build"
          }
        ]
      end

      def format_schema_error(error)
        {
          path: error.fetch("data_pointer", "/"),
          message: error.fetch("type", "schema_error")
        }
      end
    end
  end
end
