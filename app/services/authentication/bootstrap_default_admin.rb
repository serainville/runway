module Authentication
  class BootstrapDefaultAdmin
    Result = Struct.new(:success?, :user, :created, :generated_password, :error, :message, keyword_init: true)

    def self.call(email:, name:, username: nil, password: nil)
      new(email: email, name: name, username: username, password: password).call
    end

    def initialize(email:, name:, username: nil, password: nil)
      @email = email.to_s.strip.downcase
      @name = name
      @username = username
      @password = password
    end

    def call
      user = User.find_by(email: email)
      generated_password = nil
      created = false

      if user
        updates = { role: "admin", username: resolved_username }

        if password.present? || user.password_digest.blank?
          generated_password = resolved_password
          updates[:password] = generated_password
          updates[:password_confirmation] = generated_password
        end

        unless user.update(updates)
          return Result.new(success?: false, error: :validation_failed, message: user.errors.full_messages.to_sentence)
        end
      else
        generated_password = resolved_password
        user = User.new(
          name: name,
          email: email,
          username: resolved_username,
          role: "admin",
          password: generated_password,
          password_confirmation: generated_password
        )

        unless user.save
          return Result.new(success?: false, error: :validation_failed, message: user.errors.full_messages.to_sentence)
        end

        user.external_identities.find_or_create_by!(provider: "local", external_subject: user.email)
        created = true
      end

      AuditEvents::Record.call(
        actor: user,
        action: created ? "user.admin_bootstrapped" : "user.admin_bootstrap_verified",
        auditable: user,
        metadata: {
          email: user.email,
          generated_password: generated_password.present?
        }
      )

      Result.new(success?: true, user: user, created: created, generated_password: generated_password)
    end

    private

    attr_reader :email, :name, :username, :password

    def resolved_username
      base = username.presence || email.to_s.split("@").first
      normalized = base.to_s.strip.downcase.gsub(/[^a-z0-9_]/, "")
      normalized = "admin" if normalized.blank?
      normalized
    end

    def resolved_password
      return password if password.present?

      SecureRandom.base58(24)
    end
  end
end
