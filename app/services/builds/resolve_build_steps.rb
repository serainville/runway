module Builds
  class ResolveBuildSteps
    def self.call(build:)
      new(build: build).call
    end

    def initialize(build:)
      @build = build
    end

    def call
      [build_step]
    end

    private

    attr_reader :build

    def build_step
      case build.application.build_template
      when "buildpacks"
        Builds::Templates::BuildpacksStep.call(artifact_image: artifact_image)
      else
        Builds::Templates::BuildkitStep.call(artifact_image: artifact_image)
      end
    end

    def artifact_image
      app = build.application
      registry = artifact_registry
      project_slug = app.project&.slug.to_s
      app_slug = app.slug.presence || app.name.to_s.parameterize
      tag = "sha-#{build.commit_sha}"
      "#{registry}/apps/#{project_slug}/#{app_slug}:#{tag}"
    end

    def artifact_registry
      value = ENV["RUNWAY_ARTIFACT_REGISTRY"].to_s.strip
      value = executor_env_value("RUNWAY_ARTIFACT_REGISTRY") if value.empty?
      value = "nexus" if value.empty?
      value
    end

    def executor_env_value(key)
      executor_env_config[key].to_s
    end

    def executor_env_config
      return @executor_env_config if defined?(@executor_env_config)

      path = Rails.root.join("executor", ".env")
      @executor_env_config = if File.exist?(path)
        File.read(path).each_line.each_with_object({}) do |line, memo|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("#")
          next unless stripped.include?("=")

          parsed_key, raw = stripped.split("=", 2)
          memo[parsed_key] = raw.to_s.strip.gsub(/\A["']|["']\z/, "")
        end
      else
        {}
      end
    end
  end
end
