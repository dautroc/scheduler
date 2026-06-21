FactoryBot.define do
  # Appointment factory. Uses a sequence to push each appointment forward in
  # time so several instances don't collide on the EXCLUDE constraints for the
  # same bay/technician. For overlapping/conflict tests, set starts_at/ends_at
  # and the associations explicitly in the test.
  factory :appointment do
    customer
    vehicle { association :vehicle, customer: customer }
    dealership
    service_type
    technician { association :technician, dealership: dealership }
    service_bay { association :service_bay, dealership: dealership }

    # Each appointment lands in its own 2-hour slot so they never overlap.
    sequence(:starts_at) { |n| Time.utc(2030, 1, 1, 9, 0, 0) + (n * 2).hours }
    ends_at { starts_at + 1.hour }

    status { :confirmed }
    cancelled_at { nil }
  end
end
