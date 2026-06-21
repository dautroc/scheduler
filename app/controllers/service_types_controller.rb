class ServiceTypesController < ApplicationController
  def index
    # The index renders only a technician count, not the records, so no eager
    # load — Bullet flagged the unused includes.
    @service_types = ServiceType.order(:name)
  end

  def show
    # Technicians (and their dealership) are iterated in the view, so eager-load
    # both to avoid N+1 queries.
    @service_type = ServiceType.includes(technicians: :dealership).find(params[:id])
  end
end
