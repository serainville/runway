class AuditEvent < ApplicationRecord
  belongs_to :team
  belongs_to :actor, class_name: "User", inverse_of: :audit_events
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true
  validates :occurred_at, presence: true
  validates :metadata, presence: true
end
