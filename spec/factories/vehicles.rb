FactoryBot.define do
  factory :vehicle do
    customer
    sequence(:make)  { %w[Toyota Honda Ford Tesla Subaru].sample }
    sequence(:model) { |n| "Model-#{n}" }
    year { 2022 }
    sequence(:vin) { |n| "VIN#{format('%014d', n)}" }
  end
end
