class Team < ApplicationRecord
	has_many :memberships, dependent: :destroy
	has_many :users, through: :memberships
	has_many :applications, dependent: :destroy
	has_many :audit_events, dependent: :destroy

	validates :name, presence: true, uniqueness: true
end
