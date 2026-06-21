class Customer < ApplicationRecord
  has_many :vehicles, dependent: :destroy
  has_many :appointments, dependent: :restrict_with_error

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :phone, presence: true, length: { maximum: 32 }, allow_nil: true
end
