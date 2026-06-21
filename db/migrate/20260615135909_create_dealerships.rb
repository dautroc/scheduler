class CreateDealerships < ActiveRecord::Migration[8.1]
  def change
    create_table :dealerships do |t|
      t.string :name, null: false
      t.string :address

      t.timestamps
    end
  end
end
