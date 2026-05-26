class DeploymentTarget < ApplicationRecord
	has_many :environments, dependent: :restrict_with_error

	validates :name, presence: true, uniqueness: true
end
