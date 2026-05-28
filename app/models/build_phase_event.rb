class BuildPhaseEvent < ApplicationRecord
  PHASES = %w[lint tests image_build].freeze
  STATUSES = %w[running succeeded failed].freeze

  belongs_to :build

  validates :phase, presence: true, inclusion: { in: PHASES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reported_at, presence: true
end
