module Environments
  class CreateDefaultForApplication
    DEFAULT_ENVIRONMENT_NAME = "nonp".freeze

    def self.call(application:)
      deployment_target = DeploymentTargets::SeedDefault.call

      application.environments.create!(
        name: DEFAULT_ENVIRONMENT_NAME,
        default: true,
        deployment_target: deployment_target
      )
    end
  end
end
