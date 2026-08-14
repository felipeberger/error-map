FactoryBot.define do
  factory :payload do
    association :error_event
    body { { "email" => "user@example.com" } }
    content_type { "application/json" }
  end
end
