-- MediVault consolidated schema reference
-- Generated from the project's 22 ordered migration files.
--
-- IMPORTANT:
--   This file is a human-readable reference, NOT the migration runner.
--   Do not execute this file against an existing database. Some migrations
--   depend on being applied in separate transactions (for example, adding an
--   enum value), and migration history is tracked in schema_migrations.
--   For database creation/upgrades, use: npm run db:migrate
--
-- Source of truth for changes: db/migrations/*.sql
-- PostgreSQL schema: public



-- ============================================================================
-- Migration 001_create_users.sql
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
  CREATE TYPE user_role AS ENUM ('patient', 'doctor', 'pharmacy');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL DEFAULT '',
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role user_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS users_email_idx ON users (email);


-- ============================================================================
-- Migration 002_create_patient_profiles.sql
-- ============================================================================
CREATE TABLE IF NOT EXISTS patient_profiles (
  patient_user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  phone VARCHAR(30),
  address TEXT,
  blood_type VARCHAR(3),
  allergies TEXT,
  emergency_contact_name VARCHAR(200),
  emergency_contact_phone VARCHAR(30),
  emergency_contact_relationship VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT patient_profiles_birth_date_check CHECK (date_of_birth <= CURRENT_DATE),
  CONSTRAINT patient_profiles_blood_type_check CHECK (
    blood_type IS NULL OR blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
  )
);


-- ============================================================================
-- Migration 003_create_medical_records.sql
-- ============================================================================
CREATE TABLE IF NOT EXISTS medical_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  uploaded_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  storage_key TEXT NOT NULL UNIQUE,
  original_filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(127) NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  title VARCHAR(200),
  category VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS medical_records_patient_created_idx
  ON medical_records (patient_user_id, created_at DESC);


-- ============================================================================
-- Migration 004_add_record_encryption.sql
-- ============================================================================
ALTER TABLE medical_records
  ADD COLUMN IF NOT EXISTS encryption_algorithm VARCHAR(32),
  ADD COLUMN IF NOT EXISTS encrypted_data_key BYTEA,
  ADD COLUMN IF NOT EXISTS data_key_iv BYTEA,
  ADD COLUMN IF NOT EXISTS data_key_auth_tag BYTEA,
  ADD COLUMN IF NOT EXISTS file_iv BYTEA,
  ADD COLUMN IF NOT EXISTS file_auth_tag BYTEA;

ALTER TABLE medical_records
  ADD CONSTRAINT medical_records_encryption_metadata_check CHECK (
    (encryption_algorithm IS NULL AND encrypted_data_key IS NULL AND data_key_iv IS NULL AND data_key_auth_tag IS NULL AND file_iv IS NULL AND file_auth_tag IS NULL)
    OR
    (encryption_algorithm = 'AES-256-GCM' AND encrypted_data_key IS NOT NULL AND data_key_iv IS NOT NULL AND data_key_auth_tag IS NOT NULL AND file_iv IS NOT NULL AND file_auth_tag IS NOT NULL)
  ) NOT VALID;


-- ============================================================================
-- Migration 005_add_record_hash.sql
-- ============================================================================
ALTER TABLE medical_records
  ADD COLUMN IF NOT EXISTS content_sha256 CHAR(64);

ALTER TABLE medical_records
  ADD CONSTRAINT medical_records_content_sha256_format_check CHECK (
    content_sha256 IS NULL OR content_sha256 ~ '^[0-9a-f]{64}$'
  ) NOT VALID;


-- ============================================================================
-- Migration 006_add_blockchain_integration.sql
-- ============================================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS blockchain_address VARCHAR(42);

CREATE UNIQUE INDEX IF NOT EXISTS users_blockchain_address_unique_idx
  ON users (blockchain_address) WHERE blockchain_address IS NOT NULL;

ALTER TABLE medical_records
  ADD COLUMN IF NOT EXISTS blockchain_status VARCHAR(16) NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS blockchain_record_id CHAR(66),
  ADD COLUMN IF NOT EXISTS blockchain_tx_hash CHAR(66),
  ADD COLUMN IF NOT EXISTS blockchain_registered_at TIMESTAMPTZ;

ALTER TABLE medical_records
  ADD CONSTRAINT medical_records_blockchain_status_check CHECK (blockchain_status IN ('pending', 'registered', 'failed')) NOT VALID;

CREATE UNIQUE INDEX IF NOT EXISTS medical_records_blockchain_record_id_unique_idx
  ON medical_records (blockchain_record_id) WHERE blockchain_record_id IS NOT NULL;


-- ============================================================================
-- Migration 007_add_consents.sql
-- ============================================================================
CREATE TABLE IF NOT EXISTS patient_doctor_consents (
  patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doctor_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  blockchain_tx_hash CHAR(66),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (patient_user_id, doctor_user_id),
  CONSTRAINT patient_doctor_consents_distinct_users CHECK (patient_user_id <> doctor_user_id)
);

CREATE INDEX IF NOT EXISTS patient_doctor_consents_doctor_active_idx
  ON patient_doctor_consents (doctor_user_id, expires_at)
  WHERE revoked_at IS NULL;


-- ============================================================================
-- Migration 008_create_prescriptions.sql
-- ============================================================================
CREATE TABLE IF NOT EXISTS prescriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  doctor_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  storage_key TEXT NOT NULL UNIQUE,
  original_filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(127) NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  title VARCHAR(200),
  content_sha256 CHAR(64) NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  doctor_signature TEXT NOT NULL,
  encryption_algorithm VARCHAR(32) NOT NULL CHECK (encryption_algorithm = 'AES-256-GCM'),
  encrypted_data_key BYTEA NOT NULL,
  data_key_iv BYTEA NOT NULL,
  data_key_auth_tag BYTEA NOT NULL,
  file_iv BYTEA NOT NULL,
  file_auth_tag BYTEA NOT NULL,
  blockchain_status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (blockchain_status IN ('pending', 'registered', 'failed')),
  blockchain_record_id CHAR(66) UNIQUE,
  blockchain_tx_hash CHAR(66),
  blockchain_registered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS prescriptions_patient_created_idx ON prescriptions (patient_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS prescriptions_doctor_created_idx ON prescriptions (doctor_user_id, created_at DESC);


-- ============================================================================
-- Migration 009_add_emergency_access_and_audit.sql
-- ============================================================================
ALTER TABLE medical_records
  ADD COLUMN IF NOT EXISTS is_emergency_essential BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS emergency_access_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doctor_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  blockchain_tx_hash CHAR(66),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT emergency_access_grants_distinct_users CHECK (patient_user_id <> doctor_user_id)
);

CREATE INDEX IF NOT EXISTS emergency_access_grants_active_idx
  ON emergency_access_grants (patient_user_id, doctor_user_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(64) NOT NULL,
  actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  subject_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  resource_type VARCHAR(64),
  resource_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  blockchain_tx_hash CHAR(66),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS audit_events_subject_created_idx ON audit_events (subject_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS audit_events_actor_created_idx ON audit_events (actor_user_id, created_at DESC);


-- ============================================================================
-- Migration 010_add_admin_role.sql
-- ============================================================================
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'admin';


-- ============================================================================
-- Migration 011_add_user_status.sql
-- ============================================================================
DO $$
BEGIN
  CREATE TYPE user_status AS ENUM ('active', 'pending', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE users ADD COLUMN IF NOT EXISTS status user_status NOT NULL DEFAULT 'active';


-- ============================================================================
-- Migration 012_add_short_patient_id.sql
-- ============================================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS patient_id VARCHAR(16);

-- Give existing patients a stable short public identifier. UUIDs remain internal.
DO $$
DECLARE r RECORD;
DECLARE candidate TEXT;
BEGIN
  FOR r IN SELECT id FROM users WHERE role = 'patient' AND patient_id IS NULL LOOP
    LOOP
      candidate := 'MV-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE patient_id = candidate);
    END LOOP;
    UPDATE users SET patient_id = candidate WHERE id = r.id;
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS users_patient_id_unique_idx ON users(patient_id) WHERE patient_id IS NOT NULL;


-- ============================================================================
-- Migration 013_generate_patient_id.sql
-- ============================================================================
CREATE OR REPLACE FUNCTION assign_patient_public_id() RETURNS trigger AS $$
DECLARE candidate TEXT;
BEGIN
  IF NEW.role = 'patient' AND NEW.patient_id IS NULL THEN
    LOOP
      candidate := 'MV-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE patient_id = candidate);
    END LOOP;
    NEW.patient_id := candidate;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_assign_patient_id ON users;
CREATE TRIGGER users_assign_patient_id BEFORE INSERT ON users FOR EACH ROW EXECUTE FUNCTION assign_patient_public_id();


-- ============================================================================
-- Migration 014_add_record_access_requests.sql
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS medical_record_access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id UUID NOT NULL
        REFERENCES medical_records(id) ON DELETE CASCADE,
    patient_user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    doctor_user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'revoked')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ,
    CONSTRAINT medical_record_access_requests_unique
        UNIQUE (record_id, doctor_user_id),
    CONSTRAINT medical_record_access_requests_distinct_users
        CHECK (patient_user_id <> doctor_user_id)
);

CREATE INDEX IF NOT EXISTS medical_record_access_requests_patient_status_idx
    ON medical_record_access_requests
    (patient_user_id, status, requested_at DESC);

CREATE INDEX IF NOT EXISTS medical_record_access_requests_doctor_idx
    ON medical_record_access_requests
    (doctor_user_id, status, requested_at DESC);


-- ============================================================================
-- Migration 015_enforce_record_access_patient_ownership.sql
-- ============================================================================
ALTER TABLE medical_records
    ADD CONSTRAINT medical_records_id_patient_user_id_unique
    UNIQUE (id, patient_user_id);

ALTER TABLE medical_record_access_requests
    ADD CONSTRAINT medical_record_access_requests_record_patient_fk
    FOREIGN KEY (record_id, patient_user_id)
    REFERENCES medical_records (id, patient_user_id)
    ON DELETE CASCADE;


-- ============================================================================
-- Migration 016_add_user_name.sql
-- ============================================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(200);
UPDATE users SET name = split_part(email, '@', 1) WHERE name IS NULL OR btrim(name) = '';
ALTER TABLE users ALTER COLUMN name SET NOT NULL;


-- ============================================================================
-- Migration 017_add_license_id.sql
-- ============================================================================
-- Store the professional license identifier entered at registration.
ALTER TABLE users ADD COLUMN IF NOT EXISTS license_id TEXT;

-- License numbers must identify at most one account. Existing accounts without
-- a license remain intact, but cannot be used for patient consent until updated.
CREATE UNIQUE INDEX IF NOT EXISTS users_license_id_unique_idx
  ON users (LOWER(BTRIM(license_id)))
  WHERE license_id IS NOT NULL AND BTRIM(license_id) <> '';


-- ============================================================================
-- Migration 018_add_medical_record_status.sql
-- ============================================================================
ALTER TABLE users
ADD COLUMN IF NOT EXISTS medical_record_status VARCHAR(20)
NOT NULL DEFAULT 'pending'
CHECK (medical_record_status IN ('pending', 'active'));


-- ============================================================================
-- Migration 019_create_patient_emergency_profiles.sql
-- ============================================================================
CREATE TABLE IF NOT EXISTS patient_emergency_profiles (
  patient_user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  blood_group VARCHAR(3),
  emergency_contact_name VARCHAR(200),
  emergency_contact_phone VARCHAR(30),
  emergency_contact_relationship VARCHAR(100),

  allergies JSONB NOT NULL DEFAULT '[]'::jsonb,
  allergies_status VARCHAR(20) NOT NULL DEFAULT 'unknown',

  chronic_conditions JSONB NOT NULL DEFAULT '[]'::jsonb,
  chronic_conditions_status VARCHAR(20) NOT NULL DEFAULT 'unknown',

  current_medications JSONB NOT NULL DEFAULT '[]'::jsonb,
  medications_status VARCHAR(20) NOT NULL DEFAULT 'unknown',

  created_by_doctor_id UUID NOT NULL REFERENCES users(id),
  last_reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT emergency_profile_blood_group_check
    CHECK (
      blood_group IS NULL OR
      blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),

  CONSTRAINT emergency_profile_allergies_status_check
    CHECK (allergies_status IN ('unknown', 'none_known', 'provided')),

  CONSTRAINT emergency_profile_conditions_status_check
    CHECK (chronic_conditions_status IN ('unknown', 'none_known', 'provided')),

  CONSTRAINT emergency_profile_medications_status_check
    CHECK (medications_status IN ('unknown', 'none_known', 'provided')),

  CONSTRAINT emergency_profile_allergies_array_check
    CHECK (jsonb_typeof(allergies) = 'array'),

  CONSTRAINT emergency_profile_conditions_array_check
    CHECK (jsonb_typeof(chronic_conditions) = 'array'),

  CONSTRAINT emergency_profile_medications_array_check
    CHECK (jsonb_typeof(current_medications) = 'array')
);


-- ============================================================================
-- Migration 020_create_emergency_profile_audit.sql
-- ============================================================================
CREATE TABLE IF NOT EXISTS patient_emergency_profile_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_user_id UUID NOT NULL REFERENCES users(id),
  doctor_user_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(20) NOT NULL
    CHECK (action IN ('created', 'updated', 'reviewed')),
  changed_fields JSONB NOT NULL DEFAULT '{}'::jsonb,
  change_reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS patient_emergency_profile_audit_patient_idx
  ON patient_emergency_profile_audit (patient_user_id, created_at DESC);


-- ============================================================================
-- Migration 021_create_emergency_profile_access_requests.sql
-- ============================================================================
CREATE TABLE emergency_profile_access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,

    doctor_user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,

    operation VARCHAR(10) NOT NULL
        CHECK (operation IN ('create', 'update')),

    status VARCHAR(10) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),

    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ,
    used_at TIMESTAMPTZ,

    CHECK (patient_user_id <> doctor_user_id),

    CHECK (
        (status = 'pending' AND decided_at IS NULL)
        OR
        (status IN ('approved', 'rejected') AND decided_at IS NOT NULL)
    ),

    CHECK (
        status = 'approved'
        OR used_at IS NULL
    )
);

CREATE INDEX idx_emergency_profile_requests_patient
    ON emergency_profile_access_requests
    (patient_user_id, status, requested_at DESC);

CREATE INDEX idx_emergency_profile_requests_doctor
    ON emergency_profile_access_requests
    (doctor_user_id, status, requested_at DESC);

CREATE UNIQUE INDEX uq_emergency_profile_pending_request
    ON emergency_profile_access_requests
    (patient_user_id, doctor_user_id, operation)
    WHERE status = 'pending';


-- ============================================================================
-- Migration 022_add_emergency_profile_view_approval.sql
-- ============================================================================
ALTER TABLE emergency_profile_access_requests
DROP CONSTRAINT IF EXISTS emergency_profile_access_requests_operation_check;

ALTER TABLE emergency_profile_access_requests
ADD CONSTRAINT emergency_profile_access_requests_operation_check
CHECK (operation IN ('view', 'create', 'update'));
