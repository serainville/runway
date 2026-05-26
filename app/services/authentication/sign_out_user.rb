module Authentication
  class SignOutUser
    def self.call(user:)
      return unless user

      AuditEvents::Record.call(
        actor: user,
        action: "user.signed_out",
        auditable: user,
        metadata: {
          email: user.email,
          provider: "session"
        }
      )
    end
  end
end
