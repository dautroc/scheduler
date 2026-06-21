# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_15_135919) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "dealership_id", null: false
    t.virtual "during", type: :tsrange, as: "tsrange(starts_at, ends_at)", stored: true
    t.datetime "ends_at", null: false
    t.bigint "service_bay_id", null: false
    t.bigint "service_type_id", null: false
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.bigint "technician_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["dealership_id"], name: "index_appointments_on_dealership_id"
    t.index ["service_bay_id"], name: "index_appointments_on_service_bay_id"
    t.index ["service_type_id"], name: "index_appointments_on_service_type_id"
    t.index ["starts_at"], name: "index_appointments_on_starts_at"
    t.index ["status"], name: "index_appointments_on_status"
    t.index ["technician_id"], name: "index_appointments_on_technician_id"
    t.index ["vehicle_id"], name: "index_appointments_on_vehicle_id"
    t.exclusion_constraint "service_bay_id WITH =, during WITH &&", where: "cancelled_at IS NULL", using: :gist, name: "appointment_bay_exclusion"
    t.exclusion_constraint "technician_id WITH =, during WITH &&", where: "cancelled_at IS NULL", using: :gist, name: "appointment_technician_exclusion"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
  end

  create_table "dealerships", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "service_bays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dealership_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["dealership_id", "name"], name: "index_service_bays_on_dealership_id_and_name", unique: true
    t.index ["dealership_id"], name: "index_service_bays_on_dealership_id"
  end

  create_table "service_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_minutes", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_service_types_on_name", unique: true
  end

  create_table "technician_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "service_type_id", null: false
    t.bigint "technician_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_type_id"], name: "index_technician_skills_on_service_type_id"
    t.index ["technician_id", "service_type_id"], name: "index_technician_skills_on_technician_id_and_service_type_id", unique: true
    t.index ["technician_id"], name: "index_technician_skills_on_technician_id"
  end

  create_table "technicians", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dealership_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["dealership_id", "name"], name: "index_technicians_on_dealership_id_and_name", unique: true
    t.index ["dealership_id"], name: "index_technicians_on_dealership_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.datetime "updated_at", null: false
    t.string "vin"
    t.integer "year", null: false
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
    t.index ["vin"], name: "index_vehicles_on_vin", unique: true
  end

  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "dealerships"
  add_foreign_key "appointments", "service_bays"
  add_foreign_key "appointments", "service_types"
  add_foreign_key "appointments", "technicians"
  add_foreign_key "appointments", "vehicles"
  add_foreign_key "service_bays", "dealerships"
  add_foreign_key "technician_skills", "service_types"
  add_foreign_key "technician_skills", "technicians"
  add_foreign_key "technicians", "dealerships"
  add_foreign_key "vehicles", "customers"
end
