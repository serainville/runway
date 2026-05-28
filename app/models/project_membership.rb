class ProjectMembership < ApplicationRecord
  ROLES = %w[owner contributor reviewer].freeze

  belongs_to :project
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :project_id }

  def owner?
    role == "owner"
  end

  def contributor?
    role == "contributor"
  end

  def reviewer?
    role == "reviewer"
  end
end
