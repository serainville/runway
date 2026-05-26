module DeploymentTargets
  class SeedDefault
    DEFAULT_NAME = "tenant-nonp".freeze
    DEFAULT_DESCRIPTION = "Default tenant non-production target".freeze
    DEFAULT_BACKEND_TYPE = "kubernetes".freeze
    DEFAULT_ENDPOINT = "https://tenant-nonp.k8s.local".freeze
    DEFAULT_CREDENTIAL_REFERENCE = "replace-with-service-account-token".freeze
    DEFAULT_CA_BUNDLE_REFERENCE = "-----BEGIN CERTIFICATE-----\nreplace-with-ca-bundle\n-----END CERTIFICATE-----".freeze

    def self.call
      target = DeploymentTarget.find_or_initialize_by(name: DEFAULT_NAME)
      target.assign_attributes(
        description: DEFAULT_DESCRIPTION,
        backend_type: DEFAULT_BACKEND_TYPE,
        endpoint: DEFAULT_ENDPOINT,
        credential_reference: DEFAULT_CREDENTIAL_REFERENCE,
        ca_bundle_reference: DEFAULT_CA_BUNDLE_REFERENCE,
        validation_status: "pending"
      )
      target.save!
      target
    end
  end
end
