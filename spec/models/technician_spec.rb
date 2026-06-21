require 'rails_helper'

RSpec.describe Technician, type: :model do
  describe 'associations' do
    it { should belong_to(:dealership) }
    it { should have_many(:technician_skills) }
    it { should have_many(:service_types).through(:technician_skills) }
    it { should have_many(:appointments) }
  end

  describe 'validations' do
    subject { build(:technician, dealership: dealership) }
    let(:dealership) { create(:dealership) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:dealership_id).case_insensitive }
  end
end
