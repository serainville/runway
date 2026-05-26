class User < ApplicationRecord
	has_many :memberships, dependent: :destroy
	has_many :teams, through: :memberships
	has_many :audit_events, foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor

	validates :email, presence: true, uniqueness: true
	validates :name, presence: true
end
