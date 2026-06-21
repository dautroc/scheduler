class Vehicle < ApplicationRecord
  belongs_to :customer
  has_many :appointments, dependent: :restrict_with_error

  validates :make,  presence: true, length: { maximum: 64 }
  validates :model, presence: true, length: { maximum: 64 }
  validates :year,  presence: true,
                    numericality: { only_integer: true,
                                    greater_than_or_equal_to: 1900,
                                    less_than_or_equal_to: ->(_) { Time.current.year + 2 } }
  validates :vin, uniqueness: { allow_nil: true, case_sensitive: false },
                  length: { maximum: 32 }, allow_nil: true
end
