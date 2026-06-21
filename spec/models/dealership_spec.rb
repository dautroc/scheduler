require 'rails_helper'

RSpec.describe Dealership, type: :model do
  describe 'associations' do
    it { should have_many(:service_bays) }
    it { should have_many(:technicians) }
    it { should have_many(:appointments) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end
end
