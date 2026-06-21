class Technician < ApplicationRecord
  belongs_to :dealership
  has_many :technician_skills, dependent: :destroy
  has_many :service_types, through: :technician_skills
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :dealership_id, case_sensitive: false }
end
