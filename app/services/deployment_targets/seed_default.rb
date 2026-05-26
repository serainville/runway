module DeploymentTargets
  class SeedDefault
    DEFAULT_NAME = "tenant-nonp".freeze

    def self.call
      DeploymentTarget.find_or_create_by!(name: DEFAULT_NAME)
    end
  end
end
