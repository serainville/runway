class ProjectMembership < ApplicationRecord
  ROLES = %w[owner member].freeze

  belongs_to :project
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :project_id }
end
