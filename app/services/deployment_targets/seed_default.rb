module DeploymentTargets
  class SeedDefault
    DEFAULT_NAME = "tenant-nonp".freeze
    DEFAULT_DESCRIPTION = "Default tenant non-production target".freeze

    def self.call
      target = DeploymentTarget.find_or_create_by!(name: DEFAULT_NAME)
      return target if target.description == DEFAULT_DESCRIPTION

      target.update!(description: DEFAULT_DESCRIPTION)
      target
    end
  end
end
