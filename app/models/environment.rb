class Environment < ApplicationRecord
  belongs_to :application
  belongs_to :deployment_target

  validates :name, presence: true, uniqueness: { scope: :application_id, case_sensitive: false }
  validates :default, inclusion: { in: [true, false] }
end
