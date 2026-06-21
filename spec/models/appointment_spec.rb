require 'rails_helper'

RSpec.describe Appointment, type: :model do
  describe 'associations' do
    it { should belong_to(:customer) }
    it { should belong_to(:vehicle) }
    it { should belong_to(:dealership) }
    it { should belong_to(:service_type) }
    it { should belong_to(:technician) }
    it { should belong_to(:service_bay) }
  end

  describe 'validations' do
    it { should validate_presence_of(:starts_at) }
    it { should validate_presence_of(:ends_at) }
    it { should validate_presence_of(:status) }

    it 'rejects ends_at that is not after starts_at' do
      a = build(:appointment, starts_at: Time.utc(2030, 1, 1, 9), ends_at: Time.utc(2030, 1, 1, 9))
      expect(a).not_to be_valid
      expect(a.errors[:ends_at]).to be_present
    end

    it 'accepts ends_at strictly after starts_at' do
      a = build(:appointment, starts_at: Time.utc(2030, 1, 1, 9), ends_at: Time.utc(2030, 1, 1, 10))
      expect(a).to be_valid
    end
  end

  describe 'status enum' do
    it 'maps statuses to integers' do
      expect(Appointment.statuses).to eq('requested' => 0, 'confirmed' => 1, 'cancelled' => 2)
    end

    it 'defaults to confirmed' do
      a = create(:appointment)
      expect(a.status).to eq('confirmed')
    end
  end

  describe '#cancel!' do
    it 'sets status to cancelled and records cancelled_at' do
      a = create(:appointment)
      expect { a.cancel! }.to change { a.status }.to('cancelled')
                          .and change { a.cancelled_at }.from(nil)
    end
  end

  describe '#cancelled?' do
    it 'returns true for cancelled appointments' do
      expect(create(:appointment, status: :cancelled)).to be_cancelled
    end

    it 'returns false for confirmed appointments' do
      expect(create(:appointment, status: :confirmed)).not_to be_cancelled
    end
  end

  describe '.overlapping scope' do
    let(:dealership) { create(:dealership) }
    let(:bay) { create(:service_bay, dealership: dealership) }
    let(:tech) { create(:technician, dealership: dealership) }
    let(:base) { Time.utc(2030, 1, 1, 9, 0, 0) }

    it 'includes appointments whose window overlaps' do
      a1 = create(:appointment, dealership:, service_bay: bay, technician: tech,
                                 starts_at: base, ends_at: base + 1.hour)
      expect(Appointment.overlapping(base + 30.minutes, base + 90.minutes)).to include(a1)
    end

    it 'excludes appointments outside the window' do
      a1 = create(:appointment, dealership:, service_bay: bay, technician: tech,
                                 starts_at: base, ends_at: base + 1.hour)
      expect(Appointment.overlapping(base + 2.hours, base + 3.hours)).not_to include(a1)
    end

    it 'excludes cancelled appointments' do
      a1 = create(:appointment, dealership:, service_bay: bay, technician: tech,
                                 starts_at: base, ends_at: base + 1.hour, status: :cancelled)
      expect(Appointment.overlapping(base, base + 1.hour)).not_to include(a1)
    end
  end

  describe 'EXCLUDE constraints (database-level)', :db_constraint do
    let(:dealership) { create(:dealership) }
    let(:bay) { create(:service_bay, dealership: dealership) }
    let(:tech) { create(:technician, dealership: dealership) }
    let(:customer) { create(:customer) }
    let(:vehicle) { create(:vehicle, customer: customer) }
    let(:service_type) { create(:service_type, duration_minutes: 30) }
    let(:base) { Time.utc(2030, 1, 1, 9, 0, 0) }

    def make_appt(extra = {})
      Appointment.new(
        customer:, vehicle:, dealership:, service_type:, technician: tech, service_bay: bay,
        starts_at: base, ends_at: base + 30.minutes, status: :confirmed
      ).tap { |a| a.assign_attributes(extra) }
    end

    it 'prevents two overlapping appointments in the same bay' do
      make_appt.save!
      dup = make_appt(service_bay: bay, technician: create(:technician, dealership: dealership))
      expect { dup.save! }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'prevents two overlapping appointments with the same technician' do
      make_appt.save!
      dup = make_appt(service_bay: create(:service_bay, dealership: dealership), technician: tech)
      expect { dup.save! }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'allows overlapping appointments once one is cancelled' do
      first = make_appt
      first.save!
      first.cancel!
      expect { make_appt.save! }.not_to raise_error
    end

    it 'allows back-to-back (non-overlapping) appointments in the same bay' do
      make_appt.save!
      expect {
        make_appt(starts_at: base + 30.minutes, ends_at: base + 1.hour,
                  technician: create(:technician, dealership: dealership)).save!
      }.not_to raise_error
    end
  end
end
