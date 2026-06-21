class ServiceType < ApplicationRecord
  has_many :appointments, dependent: :restrict_with_error
  has_many :technician_skills, dependent: :destroy
  has_many :technicians, through: :technician_skills

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :duration_minutes,
            presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 * 60 }
end
