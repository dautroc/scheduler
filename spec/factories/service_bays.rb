FactoryBot.define do
  factory :service_bay do
    dealership
    sequence(:name) { |n| "Bay #{('A'.ord + (n - 1) % 26).chr}" }
  end
end
