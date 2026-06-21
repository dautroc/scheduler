FactoryBot.define do
  factory :dealership do
    sequence(:name)    { |n| "Dealership #{n}" }
    sequence(:address) { |n| "#{n} Garage Way" }
  end
end
