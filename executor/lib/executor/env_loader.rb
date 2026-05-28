# frozen_string_literal: true

module Executor
  module EnvLoader
    module_function

    def load!(path: default_path)
      return false unless File.exist?(path)

      File.foreach(path) do |line|
        stripped = line.strip
        next if stripped.empty? || stripped.start_with?("#")

        stripped = stripped.sub(/\Aexport\s+/, "")
        next unless stripped.include?("=")

        key, value = stripped.split("=", 2)
        ENV[key] = unquote(value.to_s.strip)
      end

      true
    end

    def default_path
      File.expand_path("../../.env", __dir__)
    end

    def unquote(value)
      value.gsub(/\A["']|["']\z/, "")
    end
    private_class_method :default_path, :unquote
  end
end