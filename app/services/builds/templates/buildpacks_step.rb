module Builds
  module Templates
    class BuildpacksStep
      DEFAULT_BUILDER = "paketobuildpacks/builder-jammy-base:latest"
      BUILDPACKS_TIMEOUT_SECONDS = 1800

      def self.call(artifact_image:, builder: nil)
        new(artifact_image: artifact_image, builder: builder).call
      end

      def initialize(artifact_image:, builder: nil)
        @artifact_image = artifact_image
        @builder = builder.presence || ENV.fetch("RUNWAY_BUILDPACKS_BUILDER", DEFAULT_BUILDER)
      end

      def call
        {
          name: "build",
          command: [
            "pack", "build", artifact_image,
            "--builder", builder,
            "--publish"
          ],
          timeout_seconds: BUILDPACKS_TIMEOUT_SECONDS
        }
      end

      private

      attr_reader :artifact_image, :builder
    end
  end
end
