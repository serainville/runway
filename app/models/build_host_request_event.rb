class BuildHostRequestEvent < ApplicationRecord
  belongs_to :build

  validates :request_method, presence: true
  validates :request_path, presence: true
  validates :response_status_code, presence: true
  validates :success, inclusion: { in: [true, false] }
end