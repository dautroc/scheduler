# This file should ensure the existence of records required to run the application in every
# environment (production, development, test). The code here is idempotent with respect to
# the email/name keys, so it can be run multiple times safely.

# ---- Dealership --------------------------------------------------------------
dealership = Dealership.find_or_create_by!(name: "Downtown Auto Service") do |d|
  d.address = "100 Garage Way, Springfield"
end

# ---- Service types -----------------------------------------------------------
oil_change = ServiceType.find_or_create_by!(name: "Oil Change") { |s| s.duration_minutes = 30 }
brake      = ServiceType.find_or_create_by!(name: "Brake Service") { |s| s.duration_minutes = 90 }
rotation   = ServiceType.find_or_create_by!(name: "Tire Rotation") { |s| s.duration_minutes = 45 }
inspection = ServiceType.find_or_create_by!(name: "Full Inspection") { |s| s.duration_minutes = 60 }

# ---- Service bays ------------------------------------------------------------
[ "Bay A", "Bay B", "Bay C" ].each do |bay_name|
  ServiceBay.find_or_create_by!(dealership: dealership, name: bay_name)
end

# ---- Technicians + qualifications -------------------------------------------
# Alice can do everything; Bob does quick services; Cara does brakes & inspection; Dan tires only.
technicians = {
  "Alice Wong"  => [ oil_change, brake, rotation, inspection ],
  "Bob Nguyen"  => [ oil_change, rotation ],
  "Cara Patel"  => [ brake, inspection ],
  "Dan Rivera"  => [ rotation ]
}
technicians.each do |name, services|
  tech = Technician.find_or_create_by!(dealership: dealership, name: name)
  services.each { |st| TechnicianSkill.find_or_create_by!(technician: tech, service_type: st) }
end

# ---- Customer + vehicle ------------------------------------------------------
customer = Customer.find_or_create_by!(email: "jordan.lee@example.com") do |c|
  c.name  = "Jordan Lee"
  c.phone = "555-0142"
end
Vehicle.find_or_create_by!(customer: customer, make: "Toyota", model: "Camry", year: 2021) do |v|
  v.vin = "4T1B11HK1MU000017"
end

puts "Seeded: #{Dealership.count} dealership(s), #{ServiceType.count} service type(s), " \
     "#{ServiceBay.count} bay(s), #{Technician.count} technician(s), " \
     "#{Customer.count} customer(s), #{Vehicle.count} vehicle(s)."
