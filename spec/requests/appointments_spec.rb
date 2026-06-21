require 'rails_helper'

RSpec.describe "Appointments", type: :request do
  # Reusable fixtures for request specs.
  let!(:dealership)  { create(:dealership) }
  let!(:bay)         { create(:service_bay, dealership: dealership, name: "Bay A") }
  let!(:oil_change)  { create(:service_type, name: "Oil Change", duration_minutes: 30) }
  let!(:tech)        { create(:technician, dealership: dealership, name: "Alice") }
  let!(:customer)    { create(:customer) }
  let!(:vehicle)     { create(:vehicle, customer: customer) }

  before do
    create(:technician_skill, technician: tech, service_type: oil_change)
  end

  describe "GET /appointments" do
    it "renders the index successfully" do
      get appointments_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Appointments")
    end
  end

  describe "GET /appointments/new" do
    it "renders the booking form" do
      get new_appointment_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Book an Appointment")
      expect(response.body).to include("Check availability")
    end
  end

  describe "POST /appointments (create)" do
    let(:tomorrow) { (Time.current + 1.day).to_date }
    let(:valid_params) do
      {
        customer_id: customer.id,
        vehicle_id: vehicle.id,
        dealership_id: dealership.id,
        service_type_id: oil_change.id,
        starts_at_date: tomorrow.to_s,
        starts_at_time: "09:00"
      }
    end

    context "when a free bay and qualified technician exist" do
      it "creates an appointment and redirects to the show page" do
        expect {
          post appointments_path, params: valid_params
        }.to change(Appointment, :count).by(1)

        appt = Appointment.last
        expect(appt).to be_confirmed
        expect(appt.technician_id).to eq(tech.id)
        expect(appt.service_bay_id).to eq(bay.id)
        expect(response).to redirect_to(appointment_path(appt))

        follow_redirect!
        expect(response.body).to include("Appointment confirmed")
      end
    end

    context "when the dealership/service are valid but no resource is free" do
      it "re-renders the form with an alert (422)" do
        # Occupy the only bay + only qualified tech for the requested window.
        create(:appointment, dealership: dealership, service_bay: bay, technician: tech,
               starts_at: Time.zone.parse("#{tomorrow} 09:00"),
               ends_at:   Time.zone.parse("#{tomorrow} 10:00"))

        expect {
          post appointments_path, params: valid_params
        }.not_to change(Appointment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Book an Appointment")
      end
    end
  end

  describe "GET /appointments/check_availability" do
    it "returns JSON indicating availability" do
      get check_availability_appointments_path(format: :json),
          params: {
            dealership_id: dealership.id,
            service_type_id: oil_change.id,
            starts_at_date: (Time.current + 1.day).to_date.to_s,
            starts_at_time: "09:00"
          }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["available"]).to be true
      expect(json["free_bays"]).to eq(1)
      expect(json["free_technicians"]).to eq(1)
    end

    it "returns unavailable JSON when the bay is busy" do
      tomorrow = (Time.current + 1.day).to_date
      create(:appointment, dealership: dealership, service_bay: bay, technician: tech,
             starts_at: Time.zone.parse("#{tomorrow} 09:00"),
             ends_at:   Time.zone.parse("#{tomorrow} 10:00"))

      get check_availability_appointments_path(format: :json),
          params: {
            dealership_id: dealership.id,
            service_type_id: oil_change.id,
            starts_at_date: tomorrow.to_s,
            starts_at_time: "09:00"
          }

      json = response.parsed_body
      expect(json["available"]).to be false
      expect(json["reason"]).to match(/bay/i)
    end
  end

  describe "PATCH /appointments/:id/cancel" do
    it "cancels the appointment and redirects to index" do
      appt = create(:appointment, dealership: dealership, service_bay: bay,
                    technician: tech, customer: customer, vehicle: vehicle,
                    service_type: oil_change,
                    starts_at: Time.current + 2.days, ends_at: Time.current + 2.days + 30.minutes)
      expect {
        patch cancel_appointment_path(appt)
      }.to change { appt.reload.status }.to("cancelled")
      expect(response).to redirect_to(appointments_path)
    end
  end
end
