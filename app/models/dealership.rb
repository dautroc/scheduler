class Dealership < ApplicationRecord
  has_many :service_bays, dependent: :destroy
  has_many :technicians,  dependent: :destroy
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :address, length: { maximum: 255 }, allow_nil: true
end
