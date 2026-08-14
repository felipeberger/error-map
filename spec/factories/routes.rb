FactoryBot.define do
  factory :route do
    sequence(:path) { |n| "/users/#{n}" }
    http_method { "POST" }
    service { "api" }
    environment { "test" }
  end
end
