# BookingService encapsulates the resource-constrained appointment allocation.
#
# Given a customer, vehicle, dealership, service type, and desired start time,
# it atomically:
#   1. computes the required window from service_type.duration_minutes,
#   2. finds a ServiceBay that is free for the whole window,
#   3. finds a Technician who (a) belongs to the dealership, (b) is qualified
#      for the requested service type (via technician_skills), and (c) is free
#      for the whole window,
#   4. creates a confirmed Appointment record.
#
# Race-safety is provided at TWO layers:
#   * Application: a SERIALIZABLE transaction + SELECT ... FOR UPDATE on the
#     candidate bays/technicians prevents two concurrent requests from picking
#     the same resource.
#   * Database: the EXCLUDE USING gist constraints on appointments(during) are
#     the definitive backstop — even if two transactions slipped past the app
#     check, Postgres rejects the second INSERT with a constraint violation,
#     which we translate into a friendly NotAvailable.
class BookingService
  class Error < StandardError; end

  # Raised when the request cannot be fulfilled. Carries a user-facing message.
  class NotAvailable < Error; end
  class NoBayAvailable < NotAvailable; end
  class NoTechnicianAvailable < NotAvailable; end
  class InvalidRequest < Error; end

  # Result value so callers can branch without rescuing exceptions in the
  # success path. BookingService.book! still raises on failure (see below).
  Result = Struct.new(:success, :appointment, :error, keyword_init: true)

  # Book an appointment. Returns the confirmed Appointment on success.
  # Raises a subclass of BookingService::NotAvailable when no suitable
  # combination of free bay + qualified free technician exists.
  #
  # @param customer [Customer]
  # @param vehicle [Vehicle]
  # @param dealership [Dealership]
  # @param service_type [ServiceType]
  # @param starts_at [ActiveSupport::TimeWithZone, Time]
  def self.book!(customer:, vehicle:, dealership:, service_type:, starts_at:)
    new(customer:, vehicle:, dealership:, service_type:, starts_at:).book!
  end

  # Non-raising variant. Returns a Result with +success+ true/false. Useful for
  # controllers that want to render form errors without exception handling.
  def self.book(...)
    new(...).book
  end

  def initialize(customer:, vehicle:, dealership:, service_type:, starts_at:)
    @customer      = customer
    @vehicle       = vehicle
    @dealership    = dealership
    @service_type  = service_type
    @starts_at     = starts_at
  end

  def book!
    validate_inputs!
    perform_booking
  end

  def book
    appointment = perform_booking
    Result.new(success: true, appointment: appointment)
  rescue NotAvailable => e
    Result.new(success: false, error: e)
  end

  # Read-only availability check that does NOT create an appointment.
  # Returns a hash describing whether a free bay + qualified free technician
  # exist for the requested window. Satisfies the "Real-Time Availability
  # Check" requirement for the UI's "Check availability" action.
  def self.check_availability(dealership:, service_type:, starts_at:)
    return { available: false, reason: "Start time is required." } if starts_at.blank?
    return { available: false, reason: "Start time must be in the future." } if starts_at < Time.current

    ends_at = starts_at + service_type.duration_minutes.minutes
    busy_bay_ids = Appointment.busy_bay_ids(dealership.id, starts_at, ends_at)
    busy_tech_ids = Appointment.busy_technician_ids(dealership.id, starts_at, ends_at)

    free_bays = dealership.service_bays.where.not(id: busy_bay_ids).count
    free_techs = dealership.technicians
                     .joins(:technician_skills)
                     .where(technician_skills: { service_type_id: service_type.id })
                     .where.not(id: busy_tech_ids)
                     .distinct.count

    if free_bays.zero?
      { available: false, reason: "No service bay is free for that time slot." }
    elsif free_techs.zero?
      { available: false, reason: "No qualified technician is free for that service and time." }
    else
      { available: true, free_bays: free_bays, free_technicians: free_techs, starts_at: starts_at, ends_at: ends_at }
    end
  end

  private

  def perform_booking
    ends_at = @starts_at + @service_type.duration_minutes.minutes

    Appointment.transaction(isolation: :serializable) do
      bay = find_free_bay(ends_at)
      raise NoBayAvailable, "No service bay is available for the requested time." if bay.nil?

      technician = find_free_qualified_technician(ends_at)
      if technician.nil?
        raise NoTechnicianAvailable,
              "No qualified technician is available for the requested service and time."
      end

      Appointment.create!(
        customer: @customer,
        vehicle: @vehicle,
        dealership: @dealership,
        service_type: @service_type,
        technician: technician,
        service_bay: bay,
        starts_at: @starts_at,
        ends_at: ends_at,
        status: :confirmed
      )
    end
  rescue ActiveRecord::SerializationFailure,
         ActiveRecord::StatementInvalid,
         ActiveRecord::RecordNotUnique => e
    # Concurrent transaction won the resource, or an exclusion constraint fired.
    # Surface as a friendly, retryable error.
    raise NotAvailable,
          "The requested time slot was just taken. Please choose another time. (#{e.class})"
  end

  def validate_inputs!
    raise InvalidRequest, "Start time is required." if @starts_at.blank?
    raise InvalidRequest, "Start time must be in the future." if @starts_at < Time.current
    raise InvalidRequest, "Customer is required." unless @customer.is_a?(Customer)
    raise InvalidRequest, "Vehicle is required."  unless @vehicle.is_a?(Vehicle)
    raise InvalidRequest, "Dealership is required." unless @dealership.is_a?(Dealership)
    raise InvalidRequest, "Service type is required." unless @service_type.is_a?(ServiceType)

    unless @vehicle.customer_id == @customer.id
      raise InvalidRequest, "Vehicle does not belong to the given customer."
    end
    return if @dealership.persisted? && @service_type.duration_minutes.to_i.positive?

    raise InvalidRequest, "Service type has no duration." if @service_type.duration_minutes.to_i <= 0
  end

  # A service bay at the dealership that has no active, overlapping appointment.
  # Locked with FOR UPDATE so concurrent bookings serialize on the same rows.
  def find_free_bay(ends_at)
    busy_ids = Appointment.busy_bay_ids(@dealership.id, @starts_at, ends_at)

    scope = @dealership.service_bays.order(:id).lock("FOR UPDATE")
    scope = scope.where.not(id: busy_ids) if busy_ids.any?
    scope.first
  end

  # A technician who is (a) at this dealership, (b) qualified for the requested
  # service type, and (c) free for the whole window. Locked for update.
  #
  # Qualified-tech IDs are resolved via a subquery so we can lock the technicians
  # rows directly — Postgres forbids `FOR UPDATE` together with `DISTINCT` or a
  # `GROUP BY`, so we avoid a join+distinct here.
  def find_free_qualified_technician(ends_at)
    busy_ids = Appointment.busy_technician_ids(@dealership.id, @starts_at, ends_at)
    qualified_ids = TechnicianSkill.where(service_type_id: @service_type.id).pluck(:technician_id)

    return nil if qualified_ids.empty?

    scope = @dealership.technicians
             .where(id: qualified_ids)
             .order(:id)
             .lock("FOR UPDATE")
    scope = scope.where.not(id: busy_ids) if busy_ids.any?
    scope.first
  end
end
