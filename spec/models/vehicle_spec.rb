require 'rails_helper'

RSpec.describe Vehicle, type: :model do
  describe 'associations' do
    it { should belong_to(:customer) }
    it { should have_many(:appointments) }
  end

  describe 'validations' do
    subject { create(:vehicle) }
    it { should validate_presence_of(:make) }
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:year) }
    it { should validate_uniqueness_of(:vin).allow_nil.case_insensitive }

    it 'rejects a year before 1900' do
      expect(build(:vehicle, year: 1800)).not_to be_valid
    end

    it 'rejects a year too far in the future' do
      expect(build(:vehicle, year: Time.current.year + 5)).not_to be_valid
    end

    it 'accepts the current year' do
      expect(build(:vehicle, year: Time.current.year)).to be_valid
    end
  end
end
