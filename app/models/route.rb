class Route < ApplicationRecord
  has_many :error_events, dependent: :destroy
  has_many :payload_field_stats, dependent: :destroy

  validates :path, :http_method, presence: true
end
