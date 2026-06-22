# Service Appointment Scheduler

A resource-constrained appointment scheduler for vehicle service dealerships.
A customer requests an appointment for a specific **vehicle**, **service type**,
and **dealership** at a desired time; the system atomically confirms it only if
both a free **service bay** and a **qualified technician** are available for the
entire service duration, then persists a confirmed **Appointment** record.

Built with **Ruby on Rails 8** and **PostgreSQL**.

## Core design — how double-booking is prevented

This is the crux of the application. Two layers guarantee that a service bay
and a technician can never be double-booked:

1. **Database level (definitive).** The `appointments` table has a generated
   `during tsrange` column derived from `starts_at`/`ends_at`, and two `EXCLUDE
   USING gist` constraints:

   ```sql
   EXCLUDE USING gist (service_bay_id WITH =, during WITH &&) WHERE (cancelled_at IS NULL)
   EXCLUDE USING gist (technician_id  WITH =, during WITH &&) WHERE (cancelled_at IS NULL)
   ```

   Postgres physically rejects any INSERT that overlaps an existing appointment
   for the same bay (or technician). Partial on `cancelled_at IS NULL` so a
   cancelled appointment frees its slot. Requires the `btree_gist` extension
   (enabled in the migration).

2. **Application level (friendly UX).** [`BookingService`](app/services/booking_service.rb)
   runs in a `SERIALIZABLE` transaction, locks candidate bays/technicians with
   `SELECT ... FOR UPDATE`, and only assigns a bay/tech that is free for the
   whole window *and* (for technicians) qualified for the requested service type
   via `technician_skills`. On a conflict it raises a typed
   `BookingService::NotAvailable` with a human message rather than a 500.

## Domain model

```mermaid
erDiagram
    Customer ||--o{ Vehicle : owns
    Customer ||--o{ Appointment : books
    Vehicle ||--o{ Appointment : used-in
    Dealership ||--o{ Appointment : hosts
    Dealership ||--o{ ServiceBay : contains
    Dealership ||--o{ Technician : employs
    Appointment ||--|| ServiceBay : uses
    Appointment ||--|| Technician : assigned-to
    Appointment ||--|| ServiceType : for
    Technician ||--o{ TechnicianSkill : has
    TechnicianSkill ||--|| ServiceType : qualifies-for
```

- **Appointment** ties together customer, vehicle, dealership, service type,
  the allocated technician and service bay, plus `starts_at`/`ends_at`/`status`.
- **TechnicianSkill** is the qualification join (a technician is only assignable
  to a service type they have a skill row for).
- **ServiceType.duration_minutes** drives the appointment window (`ends_at`).

## Requirements covered

| Requirement | Where |
|-------------|-------|
| Request an appointment for a vehicle, service type, dealership, time | `AppointmentsController#create` → `BookingService.book!` |
| Real-time availability check (free bay **and** qualified free tech, whole duration) | `BookingService.check_availability` + `/appointments/check_availability` |
| Persistent confirmed record linking customer, vehicle, technician, bay | `Appointment` record created in the `SERIALIZABLE` transaction |

## Getting started

```bash
bin/setup           # install gems, create & migrate DBs, seed
bin/dev             # start the server (http://localhost:3000)
```

Requires Ruby 4.0+ and PostgreSQL 13+. The seed data creates one dealership,
3 bays, 4 technicians (with varied qualifications), 4 service types, and a
sample customer + vehicle, so the app is usable immediately.

## Using it

1. Visit **/appointments/new** (the "Book" link).
2. Pick a dealership, service type, date, and time → **Check availability**.
3. Select the customer and vehicle → **Confirm appointment**.
4. The confirmation page shows the allocated technician and bay.

Browse dealerships (`/dealerships`), service types (`/service_types`), and
customers (`/customers`) from the top nav. Add customers/vehicles from their
pages.

## Testing

```bash
bundle exec rspec
```

The suite (89 examples) covers model validations/associations, the overlap
scopes, the database `EXCLUDE` constraints directly, the `BookingService`
happy paths and every failure mode (no bay, no qualified tech, double-booking,
qualification filtering, input validation), and the request flow including the
JSON availability endpoint. [Bullet](https://github.com/flyerhzm/bullet) fails
any request spec that triggers an N+1.

## Key files

- `app/services/booking_service.rb` — the race-safe allocation core
- `app/models/appointment.rb` — enum, validations, overlap scopes
- `db/migrate/*_create_appointments.rb` — `EXCLUDE` constraints + `during` range
- `spec/services/booking_service_spec.rb` — the booking logic tests

## AI Collaboration Narrative

### High-Level Strategy

My strategy for working with GenAI on this project was built on four pillars:

1. **Domain-first, tool-second.** I led with the problem description — resource-constrained booking with double-booking prevention — and let the AI propose solutions, rather than dictating specific tools. This surfaced options (exclusion constraints, SERIALIZABLE transactions, range types) I evaluated independently.

2. **Iterative refinement over prompting perfection.** Instead of trying to craft one perfect prompt for the entire system, I broke the work into small, verifiable chunks: database schema, service object, controllers, views, tests. At each step I reviewed the output, identified issues, and fed corrections back to the AI.

3. **Tests as specification.** I wrote test cases first (or specified test scenarios for the AI to code), treating tests as the executable specification. The booking service test file covers every failure mode — no bay, no qualified tech, qualification filtering, double-booking, input validation — which forced the implementation to be complete.

4. **Defense-in-depth verification.** I never trusted generated code at face value. Every SQL constraint was confirmed by reading the raw SQL in the migration. Every transaction behavior was verified by reasoning about concurrent access. Every route was checked against the controller implementation.

### Verification and Refinement Process

| Phase | What the AI Generated | What I Verified/Corrected |
|-------|----------------------|--------------------------|
| **DB schema** | Migration with `btree_gist` and `EXCLUDE USING gist` constraints on `during` tsrange | Confirmed the `WHERE (cancelled_at IS NULL)` partial constraint allows cancelled appointments to free slots. Corrected `tstzrange` to `tsrange` — PostgreSQL rejects generated `tstzrange` columns because `timestamptz` casts are non-immutable. |
| **Booking service** | Full `BookingService` with `.book!`, `.book`, `.check_availability` | Caught `FOR UPDATE` + `DISTINCT` incompatibility — refactored to use a subquery for qualified tech IDs. Ensured `SERIALIZABLE` isolation is used (AI initially proposed `READ COMMITTED`). |
| **Controllers** | Thin controller delegating to `BookingService` | Added non-raising `.book` for clean controller flow. Ensured error handling differentiates `NotAvailable` from general failures. |
| **Views** | Two-step booking form with availability check | Verified the form submits to the correct routes. Added inline JS for customer→vehicle dropdown via JSON. |
| **Tests** | 89 examples across models, service, requests | Audited coverage: verified every business rule has a test. Ran the suite, fixed factory sequence collisions with the exclusion constraints. |

### Ensuring Final Quality

1. **Test suite as gate.** All 89 examples pass. Bullet is configured to `raise` in test — any N+1 query is a failing spec.
2. **Static analysis.** Brakeman (security), RuboCop (style), and Bundler Audit (vulnerability scanner) all pass without warnings.
3. **Database-level guarantees.** The two `EXCLUDE` constraints on `appointments.during` are the definitive correctness assertion — no application bug can bypass them.
4. **Manual smoke test.** Seed data creates a usable dealership with bays, technicians, skills, and a sample customer. The two-step booking flow was tested end-to-end in the browser.
5. **Production readiness.** Docker multi-stage build, Kamal deployment config, Solid Cache/Queue for production, jemalloc for memory, Thruster for HTTP caching.
