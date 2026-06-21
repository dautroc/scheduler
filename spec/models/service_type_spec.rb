require 'rails_helper'

RSpec.describe ServiceType, type: :model do
  describe 'associations' do
    it { should have_many(:appointments) }
    it { should have_many(:technician_skills) }
    it { should have_many(:technicians).through(:technician_skills) }
  end

  describe 'validations' do
    subject { create(:service_type) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_presence_of(:duration_minutes) }

    it 'rejects a non-positive duration' do
      expect(build(:service_type, duration_minutes: 0)).not_to be_valid
      expect(build(:service_type, duration_minutes: -5)).not_to be_valid
    end

    it 'rejects a duration over one day' do
      expect(build(:service_type, duration_minutes: 24 * 60 + 1)).not_to be_valid
    end

    it 'accepts a valid duration' do
      expect(build(:service_type, duration_minutes: 45)).to be_valid
    end
  end
end
