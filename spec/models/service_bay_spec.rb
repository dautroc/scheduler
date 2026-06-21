require 'rails_helper'

RSpec.describe ServiceBay, type: :model do
  describe 'associations' do
    it { should belong_to(:dealership) }
    it { should have_many(:appointments) }
  end

  describe 'validations' do
    subject { build(:service_bay, dealership: dealership) }
    let(:dealership) { create(:dealership) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:dealership_id).case_insensitive }
  end
end
