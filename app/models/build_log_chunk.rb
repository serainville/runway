class BuildLogChunk < ApplicationRecord
  PHASES = BuildPhaseEvent::PHASES

  belongs_to :build

  validates :phase, presence: true, inclusion: { in: PHASES }
  validates :sequence, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :chunk, presence: true, length: { maximum: 16_384 }
  validates :reported_at, presence: true
end
