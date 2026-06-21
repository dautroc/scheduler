FactoryBot.define do
  factory :customer do
    sequence(:name)  { |n| "Customer #{n}" }
    sequence(:email) { |n| "customer#{n}@example.com" }
    sequence(:phone) { |n| "555-#{format('%04d', n)}" }
  end
end
