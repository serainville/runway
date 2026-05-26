module Vault
  class ReadSecretReference
    Result = Struct.new(:success?, :secret, :error, :message, keyword_init: true)

    def self.call(reference:)
      new(reference: reference).call
    end

    def initialize(reference:)
      @reference = reference.to_s
    end

    def call
      return invalid_reference if reference.blank?

      case parsed_scheme
      when "env"
        read_env_reference
      when "vault"
        read_vault_reference_from_env_bridge
      else
        invalid_reference
      end
    end

    private

    attr_reader :reference

    def parsed_scheme
      reference.split("://", 2).first
    end

    def read_env_reference
      key = reference.split("://", 2).last
      value = ENV[key]
      return not_found if value.blank?

      Result.new(success?: true, secret: value)
    end

    # MVP bridge: ops can sync a Vault secret into an env var key derived from the reference.
    def read_vault_reference_from_env_bridge
      key = "RUNWAY_VAULT_REF_#{reference.gsub(/[^a-zA-Z0-9]/, "_").upcase}"
      value = ENV[key]
      return not_found if value.blank?

      Result.new(success?: true, secret: value)
    end

    def invalid_reference
      Result.new(success?: false, error: :invalid_reference, message: "Credential reference is invalid")
    end

    def not_found
      Result.new(success?: false, error: :not_found, message: "Credential reference cannot be resolved")
    end
  end
end
