FactoryBot.define do
  factory :service_type do
    sequence(:name) { |n| "Service #{n}" }
    duration_minutes { 30 }
  end
end
