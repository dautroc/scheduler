class DealershipsController < ApplicationController
  def index
    # The index only renders counts (bays/technicians), not the records
    # themselves, so we don't eager-load — Bullet flagged the unused includes.
    @dealerships = Dealership.order(:name)
  end

  def show
    # Technicians + their qualified service_types are iterated in the view, so
    # eager-load both to avoid an N+1 per technician.
    @dealership = Dealership.includes(service_bays: [], technicians: :service_types).find(params[:id])
  end
end
