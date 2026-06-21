class VehiclesController < ApplicationController
  before_action :set_customer

  def new
    @vehicle = @customer.vehicles.new
  end

  def create
    @vehicle = @customer.vehicles.new(vehicle_params)
    if @vehicle.save
      redirect_to customer_path(@customer), notice: "Vehicle added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # JSON list of vehicles for a customer (used by the booking form via fetch).
  def index
    render json: @customer.vehicles.order(:make).as_json(only: %i[id make model year vin])
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def vehicle_params
    params.require(:vehicle).permit(:make, :model, :year, :vin)
  end
end
