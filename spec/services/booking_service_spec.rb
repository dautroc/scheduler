require 'rails_helper'

RSpec.describe BookingService, type: :model do
  # Common fixture: one dealership, two bays, two technicians, two service types.
  # Alice is qualified for oil_change only; Bob for brake only.
  let(:dealership)    { create(:dealership) }
  let(:bay_a)         { create(:service_bay, dealership: dealership, name: 'Bay A') }
  let(:bay_b)         { create(:service_bay, dealership: dealership, name: 'Bay B') }
  let(:alice)         { create(:technician, dealership: dealership, name: 'Alice') }
  let(:bob)           { create(:technician, dealership: dealership, name: 'Bob') }
  let(:oil_change)    { create(:service_type, name: 'Oil Change', duration_minutes: 30) }
  let(:brake)         { create(:service_type, name: 'Brake Service', duration_minutes: 90) }
  let(:customer)      { create(:customer) }
  let(:vehicle)       { create(:vehicle, customer: customer) }
  let(:starts_at)     { Time.utc(2035, 6, 1, 9, 0, 0) } # future

  before do
    [ bay_a, bay_b ]
    create(:technician_skill, technician: alice, service_type: oil_change)
    create(:technician_skill, technician: bob,   service_type: brake)
  end

  describe '.book!' do
    context 'happy path' do
      it 'creates a confirmed appointment with a free bay and qualified technician' do
        appt = BookingService.book!(
          customer:, vehicle:, dealership:, service_type: oil_change, starts_at:
        )
        expect(appt).to be_persisted
        expect(appt.status).to eq('confirmed')
        expect(appt.starts_at).to eq(starts_at)
        expect(appt.ends_at).to eq(starts_at + 30.minutes)
        expect(appt.service_bay).to be_present
        expect(appt.service_bay.dealership_id).to eq(dealership.id)
        # Alice is the only qualified tech for oil_change
        expect(appt.technician_id).to eq(alice.id)
      end

      it 'assigns a bay from the dealership' do
        appt = BookingService.book!(customer:, vehicle:, dealership:, service_type: brake, starts_at:)
        expect(dealership.service_bays).to include(appt.service_bay)
      end
    end

    context 'when all bays are busy' do
      it 'raises NoBayAvailable' do
        # Only one bay, fully occupied for the window.
        only_bay = create(:service_bay, dealership: dealership, name: 'Only Bay')
        dealership.service_bays.where.not(id: only_bay.id).destroy_all
        create(:appointment, dealership: dealership, service_bay: only_bay,
               technician: alice, starts_at: starts_at, ends_at: starts_at + 1.hour)

        expect {
          BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
        }.to raise_error(BookingService::NoBayAvailable)
      end
    end

    context 'when no qualified technician is free' do
      it 'raises NoTechnicianAvailable even though a bay is free' do
        # Alice is the only qualified tech for oil_change; book her elsewhere
        # in an overlapping window.
        create(:appointment, dealership: dealership,
               service_bay: bay_a, technician: alice,
               starts_at: starts_at, ends_at: starts_at + 1.hour)

        expect {
          BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
        }.to raise_error(BookingService::NoTechnicianAvailable)
      end
    end

    context 'qualification filtering' do
      it 'never selects an unqualified technician even if they are idle' do
        # Bob is free but unqualified for oil_change; Alice is busy.
        create(:appointment, dealership: dealership,
               service_bay: bay_a, technician: alice,
               starts_at: starts_at, ends_at: starts_at + 1.hour)

        expect {
          BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
        }.to raise_error(BookingService::NoTechnicianAvailable)
      end
    end

    context 'double-booking prevention' do
      it 'books two non-overlapping appointments for the same bay + technician' do
        first = BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
        expect {
          BookingService.book!(customer:, vehicle:, dealership:,
                               service_type: oil_change, starts_at: starts_at + 1.hour)
        }.to change(Appointment, :count).by(1)
      end

      it 'does not allow a second appointment to grab the only bay at an overlapping time' do
        # Reduce to a single bay + single qualified tech so the conflict is forced.
        dealership.service_bays.where.not(id: bay_a.id).destroy_all
        first = BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
        expect(first.service_bay_id).to eq(bay_a.id)

        expect {
          BookingService.book!(customer:, vehicle:, dealership:,
                               service_type: oil_change, starts_at: starts_at + 15.minutes)
        }.to raise_error(BookingService::NotAvailable)
      end
    end

    context 'input validation' do
      it 'rejects a start time in the past' do
        expect {
          BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change,
                               starts_at: 1.hour.ago)
        }.to raise_error(BookingService::InvalidRequest, /future/)
      end

      it 'rejects a blank start time' do
        expect {
          BookingService.book!(customer:, vehicle:, dealership:, service_type: oil_change, starts_at: nil)
        }.to raise_error(BookingService::InvalidRequest, /required/i)
      end

      it 'rejects a vehicle that does not belong to the customer' do
        other_customer = create(:customer)
        other_vehicle  = create(:vehicle, customer: other_customer)
        expect {
          BookingService.book!(customer:, vehicle: other_vehicle, dealership:, service_type: oil_change, starts_at:)
        }.to raise_error(BookingService::InvalidRequest, /belong/)
      end
    end
  end

  describe '.book (non-raising)' do
    it 'returns a successful Result on success' do
      result = BookingService.book(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
      expect(result.success).to be true
      expect(result.appointment).to be_persisted
      expect(result.error).to be_nil
    end

    it 'returns a failed Result (not raising) when nothing is available' do
      dealership.service_bays.where.not(id: bay_a.id).destroy_all
      create(:appointment, dealership: dealership, service_bay: bay_a, technician: alice,
             starts_at: starts_at, ends_at: starts_at + 1.hour)
      result = BookingService.book(customer:, vehicle:, dealership:, service_type: oil_change, starts_at:)
      expect(result.success).to be false
      expect(result.error).to be_a(BookingService::NotAvailable)
    end
  end

  describe '.check_availability (read-only)' do
    it 'reports availability when a free bay + qualified tech exist' do
      result = BookingService.check_availability(dealership:, service_type: oil_change, starts_at:)
      expect(result[:available]).to be true
      expect(result[:free_bays]).to eq(2)
      expect(result[:free_technicians]).to eq(1) # only Alice
    end

    it 'reports unavailable when all bays are busy' do
      only_bay = create(:service_bay, dealership: dealership, name: 'Only Bay')
      dealership.service_bays.where.not(id: only_bay.id).destroy_all
      create(:appointment, dealership: dealership, service_bay: only_bay, technician: alice,
             starts_at: starts_at, ends_at: starts_at + 1.hour)

      result = BookingService.check_availability(dealership:, service_type: oil_change, starts_at:)
      expect(result[:available]).to be false
      expect(result[:reason]).to match(/bay/i)
    end

    it 'reports unavailable when no qualified technician is free' do
      create(:appointment, dealership: dealership, service_bay: bay_a, technician: alice,
             starts_at: starts_at, ends_at: starts_at + 1.hour)
      result = BookingService.check_availability(dealership:, service_type: oil_change, starts_at:)
      expect(result[:available]).to be false
      expect(result[:reason]).to match(/technician/i)
    end

    it 'does not create any appointment' do
      expect {
        BookingService.check_availability(dealership:, service_type: oil_change, starts_at:)
      }.not_to change(Appointment, :count)
    end
  end
end
