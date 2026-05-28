module Builds
  class PumpQueueJob < ApplicationJob
    queue_as :default

    MAX_ITERATIONS = 20

    def perform(dispatcher: Builds::DispatchPending, max_iterations: MAX_ITERATIONS, requeue: true)
      max_iterations.times do
        pending_build = Build.pending.order(:created_at).first
        break unless pending_build

        dispatcher.call(build: pending_build)
      end

      return unless requeue
      return unless Build.where(status: %w[pending running]).exists?

      self.class.set(wait: 3.seconds).perform_later
    end
  end
end
