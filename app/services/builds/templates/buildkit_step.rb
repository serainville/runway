module Builds
  module Templates
    class BuildkitStep
      BUILDKIT_PLATFORM = "linux/amd64"
      BUILDKIT_TIMEOUT_SECONDS = 1200

      def self.call(artifact_image:)
        new(artifact_image: artifact_image).call
      end

      def initialize(artifact_image:)
        @artifact_image = artifact_image
      end

      def call
        {
          name: "build",
          command: [
            "docker", "buildx", "build",
            "--platform", BUILDKIT_PLATFORM,
            "-t", artifact_image,
            "--push",
            "."
          ],
          timeout_seconds: BUILDKIT_TIMEOUT_SECONDS
        }
      end

      private

      attr_reader :artifact_image
    end
  end
end
