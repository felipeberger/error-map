class ErrorEvent < ApplicationRecord
  belongs_to :route
  has_one :payload, dependent: :destroy

  validates :datadog_event_id, presence: true, uniqueness: true
end
