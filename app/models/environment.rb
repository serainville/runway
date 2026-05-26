class Environment < ApplicationRecord
  belongs_to :application

  validates :name, presence: true, uniqueness: { scope: :application_id, case_sensitive: false }
  validates :default, inclusion: { in: [true, false] }
end
