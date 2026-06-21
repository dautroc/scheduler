class Appointment < ApplicationRecord
  # status: requested -> confirmed -> cancelled (confirmed is the normal state)
  enum :status, { requested: 0, confirmed: 1, cancelled: 2 }

  belongs_to :customer
  belongs_to :vehicle
  belongs_to :dealership
  belongs_to :service_type
  belongs_to :technician
  belongs_to :service_bay

  validates :starts_at, presence: true
  validates :ends_at,   presence: true
  validates :status,    presence: true
  validate :ends_after_starts

  scope :upcoming, -> { where(status: :confirmed).where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :recent,   -> { order(starts_at: :desc) }
  # Explicit rather than relying on the enum's auto-generated `not_cancelled`.
  scope :active, -> { where.not(status: :cancelled) }

  # Active (non-cancelled) appointments whose [starts_at, ends_at) overlaps the
  # given window. Used by BookingService to find free bays/technicians. Uses the
  # stored `during` range via a half-open overlap test.
  scope :overlapping, lambda { |starts_at, ends_at|
    active.where("during && tsrange(?, ?)", starts_at, ends_at)
  }

  # Convenience scopes for the booking service: which bays/technicians are busy.
  def self.busy_bay_ids(dealership_id, starts_at, ends_at)
    overlapping(starts_at, ends_at).where(dealership_id: dealership_id).distinct.pluck(:service_bay_id)
  end

  def self.busy_technician_ids(dealership_id, starts_at, ends_at)
    overlapping(starts_at, ends_at).where(dealership_id: dealership_id).distinct.pluck(:technician_id)
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  def cancelled?
    status == "cancelled"
  end

  private

  def ends_after_starts
    return unless starts_at && ends_at

    errors.add(:ends_at, "must be after start time") unless ends_at > starts_at
  end
end
