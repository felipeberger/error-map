FactoryBot.define do
  factory :error_event do
    association :route
    sequence(:datadog_event_id) { |n| "evt-#{n}" }
    occurred_at { Time.current }
    status_code { 500 }
    error_class { "RuntimeError" }
    message { "Something went wrong" }
  end
end
