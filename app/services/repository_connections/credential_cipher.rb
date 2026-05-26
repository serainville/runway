module RepositoryConnections
  class CredentialCipher
    def self.encrypt(value)
      encryptor.encrypt_and_sign(value.to_s)
    end

    def self.decrypt(value)
      return "" if value.blank?

      encryptor.decrypt_and_verify(value)
    end

    def self.encryptor
      secret = Rails.application.secret_key_base
      key = ActiveSupport::KeyGenerator.new(secret).generate_key("repository-connections", ActiveSupport::MessageEncryptor.key_len)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
