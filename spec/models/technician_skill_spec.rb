require 'rails_helper'

RSpec.describe TechnicianSkill, type: :model do
  describe 'associations' do
    it { should belong_to(:technician) }
    it { should belong_to(:service_type) }
  end

  describe 'validations' do
    let(:tech) { create(:technician) }
    let(:service_type) { create(:service_type) }

    it 'prevents the same (technician, service_type) pair twice' do
      create(:technician_skill, technician: tech, service_type: service_type)
      expect(build(:technician_skill, technician: tech, service_type: service_type)).not_to be_valid
    end

    it 'allows a technician to qualify for distinct service types' do
      create(:technician_skill, technician: tech, service_type: service_type)
      other = create(:service_type)
      expect(build(:technician_skill, technician: tech, service_type: other)).to be_valid
    end
  end
end
