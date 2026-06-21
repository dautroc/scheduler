class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show]

  def index
    # The index renders only a vehicle count, not the records, so no eager
    # load — Bullet flagged the unused includes.
    @customers = Customer.order(:name)
  end

  def show
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      redirect_to customer_path(@customer), notice: "Customer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :email, :phone)
  end
end
