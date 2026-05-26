class User < ApplicationRecord
	has_secure_password

	has_many :memberships, dependent: :destroy
	has_many :teams, through: :memberships
	has_many :project_memberships, dependent: :destroy
	has_many :projects, through: :project_memberships
	has_many :audit_events, foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor
	has_many :external_identities, dependent: :destroy

	before_validation :normalize_email

	validates :email, presence: true, uniqueness: { case_sensitive: false }
	validates :name, presence: true
	validates :password, length: { minimum: 8 }, if: :password_required?

	private

	def normalize_email
		self.email = email.to_s.strip.downcase
	end

	def password_required?
		password_digest.blank? || password.present?
	end
end
