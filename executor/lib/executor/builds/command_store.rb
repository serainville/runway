# frozen_string_literal: true

require "thread"

module Executor
  module Builds
    class CommandStore
      def initialize
        @mutex = Mutex.new
        @commands = {}
        @queue = Queue.new
      end

      def put(command_id:, data:)
        @mutex.synchronize do
          @commands[command_id] = data
        end
      end

      def get(command_id:)
        @mutex.synchronize do
          @commands[command_id]
        end
      end

      def update(command_id:)
        @mutex.synchronize do
          current = @commands[command_id]
          return nil if current.nil?

          @commands[command_id] = yield(current.dup)
        end
      end

      def enqueue(command_id:)
        @queue << command_id
      end

      def pop_command_id
        @queue.pop
      end

      def public_record(command_id:)
        record = get(command_id: command_id)
        return nil if record.nil?

        record.reject { |key, _| key == "_payload" }
      end
    end
  end
end
