# frozen_string_literal: true

module Executor
  module Adapters
    module Kubernetes
      class RunStep
        def run_step(command:, step_name:)
          warn "Kubernetes adapter stub: #{step_name} for command #{command["command_id"]}"
          {
            status: "succeeded",
            exit_code: 0,
            message: nil,
            failure_code: nil
          }
        end
      end
    end
  end
end
