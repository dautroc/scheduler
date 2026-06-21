# The core race-safety of this app lives here.
#
# A generated `during` tstzrange column is computed from starts_at/ends_at,
# then two EXCLUDE (GiST) constraints forbid overlapping `during` ranges for
# the same service_bay_id (or technician_id) among non-cancelled appointments.
#
# The `btree_gist` extension is required so that a plain integer column
# (service_bay_id / technician_id) can participate in a GiST exclusion
# constraint alongside the tstzrange.
class CreateAppointments < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist"

    create_table :appointments do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.references :dealership, null: false, foreign_key: true
      t.references :service_type, null: false, foreign_key: true
      t.references :technician, null: false, foreign_key: true
      t.references :service_bay, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :status, null: false, default: 0
      t.datetime :cancelled_at

      t.timestamps
    end

    # Generated range column — always derived from starts_at/ends_at so it can
    # never drift from the scalar values. Uses tsrange (not tstzrange) because
    # the underlying columns are `timestamp without time zone` (Rails default);
    # tstzrange would force a timezone-dependent cast that Postgres rejects as
    # non-immutable for a generated column. Times are stored in UTC.
    execute <<~SQL
      ALTER TABLE appointments
        ADD COLUMN during tsrange
        GENERATED ALWAYS AS (tsrange(starts_at, ends_at)) STORED;
    SQL

    # The FK columns (customer/vehicle/dealership/service_type/technician/
    # service_bay) are automatically indexed by the `t.references ... index: true`
    # declarations in create_table above. Add only the non-FK columns we filter
    # or order by.
    add_index :appointments, :starts_at
    add_index :appointments, :status

    # The definitive double-booking guard. A service bay can host at most one
    # non-cancelled appointment at any instant; likewise for a technician.
    # Partial (WHERE cancelled_at IS NULL) so cancelled appointments free up
    # the slot.
    execute <<~SQL
      ALTER TABLE appointments
        ADD CONSTRAINT appointment_bay_exclusion
        EXCLUDE USING gist (service_bay_id WITH =, during WITH &&)
        WHERE (cancelled_at IS NULL);
    SQL

    execute <<~SQL
      ALTER TABLE appointments
        ADD CONSTRAINT appointment_technician_exclusion
        EXCLUDE USING gist (technician_id WITH =, during WITH &&)
        WHERE (cancelled_at IS NULL);
    SQL
  end

  def down
    drop_table :appointments
    # disable_extension "btree_gist"  # leave installed; shared across DBs
  end
end
