require 'rails_helper'

RSpec.describe Customer, type: :model do
  describe 'associations' do
    it { should have_many(:vehicles) }
    it { should have_many(:appointments) }
  end

  describe 'validations' do
    subject { create(:customer) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }

    it 'accepts a well-formed email' do
      expect(build(:customer, email: 'valid@example.com')).to be_valid
    end

    it 'rejects a malformed email' do
      expect(build(:customer, email: 'not-an-email')).not_to be_valid
    end
  end
end
