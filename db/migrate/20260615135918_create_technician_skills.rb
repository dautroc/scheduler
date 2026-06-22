class CreateTechnicianSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :technician_skills do |t|
      t.references :technician, null: false, foreign_key: true
      t.references :service_type, null: false, foreign_key: true

      t.timestamps
    end

    add_index :technician_skills, [ :technician_id, :service_type_id ], unique: true
  end
end
