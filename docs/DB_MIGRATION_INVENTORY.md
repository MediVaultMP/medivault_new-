# MediVault — Database Migration Inventory

## 1. Overview

**Project:** MediVault Backend  
**Responsible area:** Person 1 — Database Design and Migrations  
**Migration directory:** `db/migrations/`  
**Migration runner:** `src/scripts/migrate.js`  
**Migration command:** `npm run db:migrate`

The project contains 22 numbered SQL migration files totaling 15,123 bytes. All 22 migrations have been applied successfully. A subsequent migration run skipped previously applied migrations, confirming that the runner recognizes its migration history.

## 2. Migration inventory

| Migration | Purpose |
|---|---|
| `001_create_users.sql` | Create user records |
| `002_create_patient_profiles.sql` | Create patient profiles |
| `003_create_medical_records.sql` | Create medical records |
| `004_add_record_encryption.sql` | Add record encryption support |
| `005_add_record_hash.sql` | Add medical record hash support |
| `006_add_blockchain_integration.sql` | Add blockchain integration fields |
| `007_add_consents.sql` | Add patient-doctor consent support |
| `008_create_prescriptions.sql` | Create prescription storage |
| `009_add_emergency_access_and_audit.sql` | Add emergency access and audit support |
| `010_add_admin_role.sql` | Add the admin role |
| `011_add_user_status.sql` | Add user account status |
| `012_add_short_patient_id.sql` | Add short patient IDs |
| `013_generate_patient_id.sql` | Add patient ID generation |
| `014_add_record_access_requests.sql` | Add medical record access requests |
| `015_enforce_record_access_patient_ownership.sql` | Enforce patient ownership for record access |
| `016_add_user_name.sql` | Add the user name field |
| `017_add_license_id.sql` | Add professional license IDs |
| `018_add_medical_record_status.sql` | Add medical record status |
| `019_create_patient_emergency_profiles.sql` | Create patient emergency profiles |
| `020_create_emergency_profile_audit.sql` | Create emergency profile audit records |
| `021_create_emergency_profile_access_requests.sql` | Create emergency profile access requests |
| `022_add_emergency_profile_view_approval.sql` | Add emergency profile viewing approval support |

*Note: The descriptions above are based on migration filenames. Exact table, column, index, constraint, and policy changes should be verified against each SQL file.*

## 3. Migration runner behavior

The migration runner:

- Loads environment variables and requires `DATABASE_URL`.
- Connects through `src/config/database.js`.
- Creates `schema_migrations` if it does not exist.
- Sorts SQL filenames before applying migrations.
- Skips migrations whose filenames are already recorded.
- Rechecks migration history inside a transaction before applying a file.
- Applies the SQL and inserts its migration-history entry within the same transaction.
- Closes the database connection in a `finally` block.

### Important limitation

Migration history is tracked by filename, not by file checksum. Editing a previously applied migration will not automatically trigger reapplication or detect content changes. Future schema changes should be added as new numbered migration files.

## 4. Verification evidence

| Check | Result |
|---|---|
| PostgreSQL Windows service | Running |
| Environment configuration | `DATABASE_URL` detected |
| Initial migration run | All 22 migrations applied successfully |
| Repeat migration run | Previously applied migrations skipped |
| Latest backend test run | 16 test files passed |
| Tests passed | 86 |
| Tests skipped | 0 |
| Tests failed | 0 |

These results establish that the migration runner completed and the reported backend test suite passed. They do not, by themselves, establish that every database constraint, authorization rule, or production deployment configuration has been independently audited.

## 5. Remaining verification items

- [ ] Compare `db/Schema.sql` with the numbered migration chain.
- [ ] Verify database constraints, foreign keys, indexes, and delete/update behavior.
- [ ] Review transaction and connection-pool handling in `src/config/database.js`.
- [ ] Confirm the documented schema matches the actual migrated database.
- [ ] Ensure integration tests use a dedicated test database and cannot run against production.
- [ ] Record any future schema changes in new numbered migrations.
- [ ] Keep database credentials and other secrets out of source control.

## 6. Environment and security notes

Required configuration includes `DATABASE_URL` for migration execution. `DATABASE_SSL` is also read by the migration runner and defaults to `false` when unset.

Other application and test environment variables should be inventoried from the code and example configuration files. Actual credentials, connection strings containing passwords, private keys, and tokens must not be included in this document.

## 7. Ownership

**Owner:** Person 1 — Database Design and Migrations  
**Status:** Initial migration execution and repeat-run verification completed. Schema comparison and remaining database checks are pending.
