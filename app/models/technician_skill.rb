class TechnicianSkill < ApplicationRecord
  belongs_to :technician
  belongs_to :service_type

  validates :technician_id, uniqueness: { scope: :service_type_id }
end
