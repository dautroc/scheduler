class AppointmentsController < ApplicationController
  before_action :set_appointment, only: %i[show cancel]

  # GET /appointments
  def index
    # dealership is intentionally NOT eager-loaded — the index table no longer
    # renders it, and Bullet flags the unused include (the association is still
    # available lazily on the show page).
    @appointments = Appointment.includes(
      :customer, :vehicle, :technician, :service_bay, :service_type
    ).recent.limit(50)
  end

  # GET /appointments/new
  def new
    @dealerships   = Dealership.order(:name)
    @service_types = ServiceType.order(:name)
    @customers     = Customer.order(:name)
  end

  # POST /appointments
  def create
    result = BookingService.book(
      customer: Customer.find_by(id: params[:customer_id]),
      vehicle: Vehicle.find_by(id: params[:vehicle_id]),
      dealership: Dealership.find_by(id: params[:dealership_id]),
      service_type: ServiceType.find_by(id: params[:service_type_id]),
      starts_at: parse_starts_at
    )

    if result.success
      redirect_to appointment_path(result.appointment), notice: "Appointment confirmed."
    else
      err = result.error
      flash.now[:alert] = err.is_a?(BookingService::NotAvailable) ? err.message : "Could not book the appointment."
      @dealerships   = Dealership.order(:name)
      @service_types = ServiceType.order(:name)
      @customers     = Customer.order(:name)
      # Re-stick selected values for the form
      @selected = params.permit(:dealership_id, :service_type_id, :customer_id, :vehicle_id, :starts_at_date, :starts_at_time)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /appointments/:id
  def show
  end

  # GET|POST /appointments/check_availability
  # Read-only availability probe; renders JSON and the new form with a result banner.
  def check_availability
    dealership  = Dealership.find_by(id: params[:dealership_id])
    service_type = ServiceType.find_by(id: params[:service_type_id])
    starts_at   = parse_starts_at

    if dealership.nil? || service_type.nil?
      @availability = { available: false, reason: "Select a dealership and a service type." }
    else
      @availability = BookingService.check_availability(
        dealership: dealership, service_type: service_type, starts_at: starts_at
      )
    end

    respond_to do |format|
      format.html do
        @dealerships   = Dealership.order(:name)
        @service_types = ServiceType.order(:name)
        @customers     = Customer.order(:name)
        @selected = params.permit(:dealership_id, :service_type_id, :customer_id, :vehicle_id, :starts_at_date, :starts_at_time)
        render :new, status: (@availability[:available] ? :ok : :unprocessable_entity)
      end
      format.json { render json: @availability }
    end
  end

  # PATCH /appointments/:id/cancel
  def cancel
    @appointment.cancel!
    redirect_to appointments_path, notice: "Appointment cancelled."
  end

  private

  def set_appointment
    @appointment = Appointment.find(params[:id])
  end

  # The new form submits date + time as separate fields. Combine into one Time.
  def parse_starts_at
    date = params[:starts_at_date]
    time = params[:starts_at_time]
    return nil if date.blank? || time.blank?

    begin
      Time.zone.parse("#{date} #{time}")
    rescue ArgumentError
      nil
    end
  end
end
