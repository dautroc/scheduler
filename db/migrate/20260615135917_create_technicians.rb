class CreateTechnicians < ActiveRecord::Migration[8.1]
  def change
    create_table :technicians do |t|
      t.references :dealership, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :technicians, [ :dealership_id, :name ], unique: true
  end
end
