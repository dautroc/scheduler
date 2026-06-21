class ServiceBay < ApplicationRecord
  belongs_to :dealership
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :dealership_id, case_sensitive: false }
end
