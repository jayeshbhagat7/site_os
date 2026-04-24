-- ═══════════════════════════════════════════════════════════════════════════
-- SITEOS V3 — MASTER PATCH SQL
-- Umiya Associates · Jayesh Bhagat · Mumbai
-- Version: V3.4 · March 2026
--
-- RUN ORDER:
--   1. siteos_v3_setup.sql     (base schema — run ONCE on fresh project)
--   2. This file               (run ONCE after setup — all patches, safe to re-run)
--   3. batch_01..batch_09      (worker migration — 500 workers each)
--
-- All statements use IF NOT EXISTS / ON CONFLICT DO NOTHING — safe to re-run.
-- ═══════════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 1 — WORKERS: ALL ADDITIONAL COLUMNS
-- ───────────────────────────────────────────────────────────────────────────

ALTER TABLE workers ADD COLUMN IF NOT EXISTS father_name            TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS mother_name            TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS dob                    DATE;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS blood_group            TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS married                BOOLEAN DEFAULT FALSE;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS wife_name              TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS children_count         INT DEFAULT 0;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS mobile                 TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS mobile_home            TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS home_address           TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS allergy                TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS job_no                 TEXT;
-- Emergency / reference contact
ALTER TABLE workers ADD COLUMN IF NOT EXISTS relative_name          TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS relative_mobile        TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS relative_address       TEXT;
-- Introduced-by worker (FK to self)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS ref_worker_id          BIGINT REFERENCES workers(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_workers_ref_worker ON workers(ref_worker_id);
-- GTV
ALTER TABLE workers ADD COLUMN IF NOT EXISTS gtv_promise_date       DATE;  -- informational only
ALTER TABLE workers ADD COLUMN IF NOT EXISTS gtv_last_working_date  DATE;  -- last Present before GTV — used by Payroll
-- Document uploads (Supabase Storage: worker-docs bucket, must be PUBLIC)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS worker_photo_url       TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS aadhaar_photo_url      TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS pan_photo_url          TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS bank_photo_url         TEXT;
-- 6-step registration workflow status
ALTER TABLE workers ADD COLUMN IF NOT EXISTS entry_status           TEXT DEFAULT 'draft'
  CHECK (entry_status IN ('draft','supervisor_signed','sic_approved','active'));
ALTER TABLE workers ADD COLUMN IF NOT EXISTS supervisor_id          UUID REFERENCES app_users(user_id);
ALTER TABLE workers ADD COLUMN IF NOT EXISTS sic_id                 UUID REFERENCES app_users(user_id);
ALTER TABLE workers ADD COLUMN IF NOT EXISTS advance_paid           NUMERIC DEFAULT 0;
-- Building assignment
ALTER TABLE workers ADD COLUMN IF NOT EXISTS building_id            INT;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 2 — SITES: JOB ID
-- ───────────────────────────────────────────────────────────────────────────

ALTER TABLE sites ADD COLUMN IF NOT EXISTS job_id TEXT;
-- Auto-fills Job No. in New Registration wizard when site is selected.


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 3 — APP_USERS: DROP ROLE CONSTRAINT
-- ───────────────────────────────────────────────────────────────────────────
-- Allows Admin to create custom roles (e.g. "Safety Officer", "HR").

ALTER TABLE app_users DROP CONSTRAINT IF EXISTS app_users_role_check;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 4 — BUILDINGS TABLE
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS buildings (
  id             SERIAL PRIMARY KEY,
  site_id        INT  NOT NULL REFERENCES sites(site_id) ON DELETE CASCADE,
  building_name  TEXT NOT NULL,
  building_code  TEXT,
  floors         INT  DEFAULT 0,
  is_active      BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE buildings DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_buildings_site ON buildings(site_id);

-- FK on workers after buildings exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_workers_building'
  ) THEN
    ALTER TABLE workers ADD CONSTRAINT fk_workers_building
      FOREIGN KEY (building_id) REFERENCES buildings(id)
      ON DELETE SET NULL NOT VALID;
  END IF;
END $$;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 5 — WORKER PPE (source of truth — always read from here, not workers table)
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS worker_ppe (
  id                   SERIAL PRIMARY KEY,
  worker_id            INT  NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  site_id              INT  REFERENCES sites(site_id),
  helmet_issued        BOOLEAN DEFAULT FALSE,
  helmet_issue_date    DATE,
  helmet_return_date   DATE,
  belt_issued          BOOLEAN DEFAULT FALSE,
  belt_issue_date      DATE,
  belt_return_date     DATE,
  gumboot_issued       BOOLEAN DEFAULT FALSE,
  gumboot_issue_date   DATE,
  gumboot_return_date  DATE,
  issued_by            UUID REFERENCES app_users(user_id),
  worker_confirmed     BOOLEAN DEFAULT FALSE,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(worker_id)
);
ALTER TABLE worker_ppe DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_worker_ppe_worker ON worker_ppe(worker_id);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 6 — WORKER PPE LOG
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS worker_ppe_log (
  id          SERIAL PRIMARY KEY,
  worker_id   INT  NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  site_id     INT  REFERENCES sites(site_id),
  ppe_item    TEXT NOT NULL,
  action      TEXT NOT NULL CHECK (action IN ('issued','returned')),
  action_date DATE DEFAULT CURRENT_DATE,
  notes       TEXT,
  done_by     UUID REFERENCES app_users(user_id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE worker_ppe_log DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_ppe_log_worker ON worker_ppe_log(worker_id);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 7 — WORKER HISTORY LOG
-- ───────────────────────────────────────────────────────────────────────────
-- event_type: join|gtv|rejoin|left|rate_change|designation_change|site_change|transfer

CREATE TABLE IF NOT EXISTS worker_history (
  id              SERIAL PRIMARY KEY,
  worker_id       INT  REFERENCES workers(id) ON DELETE CASCADE,
  event_type      TEXT NOT NULL,
  event_date      DATE DEFAULT CURRENT_DATE,
  old_value       TEXT,
  new_value       TEXT,
  changed_by      UUID REFERENCES app_users(user_id),
  changed_by_name TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE worker_history DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_worker_history_worker ON worker_history(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_history_event  ON worker_history(event_type);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 8 — ATTENDANCE TABLES
-- ───────────────────────────────────────────────────────────────────────────

-- 8.1  Sessions (one per site per day)
CREATE TABLE IF NOT EXISTS attendance_sessions (
  id             SERIAL PRIMARY KEY,
  site_id        INT  NOT NULL REFERENCES sites(site_id) ON DELETE CASCADE,
  att_date       DATE NOT NULL,
  status         TEXT NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft','submitted','locked')),
  submitted_by   UUID REFERENCES app_users(user_id),
  submitted_at   TIMESTAMPTZ,
  locked_by      UUID REFERENCES app_users(user_id),
  locked_at      TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(site_id, att_date)
);
ALTER TABLE attendance_sessions DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_att_sessions_site   ON attendance_sessions(site_id);
CREATE INDEX IF NOT EXISTS idx_att_sessions_date   ON attendance_sessions(att_date);
CREATE INDEX IF NOT EXISTS idx_att_sessions_status ON attendance_sessions(status);

-- 8.2  Records (one per worker per session)
--      corrected_by/corrected_at/correction_note used by Mark GTV flow:
--      SIC resolves unsubmitted sessions before confirming GTV status.
CREATE TABLE IF NOT EXISTS attendance_records (
  id              SERIAL PRIMARY KEY,
  session_id      INT  NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  worker_id       INT  NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  site_id         INT  REFERENCES sites(site_id),
  att_date        DATE,
  is_present      BOOLEAN      DEFAULT TRUE,
  haajri          NUMERIC(4,2) DEFAULT 1.0,
  daily_wage      NUMERIC      DEFAULT 0,
  corrected_by    UUID REFERENCES app_users(user_id),
  corrected_at    TIMESTAMPTZ,
  correction_note TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE attendance_records DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_att_records_session ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_att_records_worker  ON attendance_records(worker_id);
CREATE INDEX IF NOT EXISTS idx_att_records_date    ON attendance_records(att_date);

-- 8.3  Building assignments per session
CREATE TABLE IF NOT EXISTS attendance_building_assignments (
  id              SERIAL PRIMARY KEY,
  session_id      INT  REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  worker_id       INT  REFERENCES workers(id) ON DELETE CASCADE,
  building_id     INT  REFERENCES buildings(id),
  is_general_work BOOLEAN DEFAULT FALSE,
  hours           NUMERIC(4,2),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE attendance_building_assignments DISABLE ROW LEVEL SECURITY;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 9 — DPR REPORTS
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dpr_reports (
  id           SERIAL PRIMARY KEY,
  site_id      INT  NOT NULL REFERENCES sites(site_id) ON DELETE CASCADE,
  building_id  INT  REFERENCES buildings(id),
  dpr_date     DATE NOT NULL,
  progress     TEXT,
  schedule     TEXT,
  hindrance    TEXT,
  status       TEXT DEFAULT 'draft' CHECK (status IN ('draft','submitted')),
  created_by   UUID REFERENCES app_users(user_id),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(site_id, dpr_date)
);
ALTER TABLE dpr_reports DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_dpr_site ON dpr_reports(site_id);
CREATE INDEX IF NOT EXISTS idx_dpr_date ON dpr_reports(dpr_date);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 10 — USER–SITE JUNCTION (multi-site SIC)
-- ───────────────────────────────────────────────────────────────────────────
-- Drives site filtering: SIC sees only their assigned sites.
-- Admin assigns in Users & Roles → per-user settings (⚙ button).

CREATE TABLE IF NOT EXISTS user_sites (
  id          SERIAL PRIMARY KEY,
  user_id     UUID REFERENCES app_users(user_id) ON DELETE CASCADE,
  site_id     INT  REFERENCES sites(site_id)     ON DELETE CASCADE,
  assigned_by UUID REFERENCES app_users(user_id),
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, site_id)
);
ALTER TABLE user_sites DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_user_sites_user ON user_sites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sites_site ON user_sites(site_id);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 11 — PER-USER POLICY OVERRIDES
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_policy_overrides (
  id          SERIAL PRIMARY KEY,
  user_id     UUID REFERENCES app_users(user_id) ON DELETE CASCADE,
  module      TEXT NOT NULL,
  can_view    BOOLEAN DEFAULT FALSE,
  can_add     BOOLEAN DEFAULT FALSE,
  can_edit    BOOLEAN DEFAULT FALSE,
  can_delete  BOOLEAN DEFAULT FALSE,
  can_approve BOOLEAN DEFAULT FALSE,
  UNIQUE(user_id, module)
);
ALTER TABLE user_policy_overrides DISABLE ROW LEVEL SECURITY;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 12 — GTV REGISTRATIONS (advance notice + 3-level approval)
-- ───────────────────────────────────────────────────────────────────────────
-- SEPARATE from "Mark GTV" (urgent/unregistered GTV via Workers screen).
-- SK registers ≥1 month in advance.
-- Cap: 10/Fitter, 10/Carpenter, 10/M/C+BRM+PLM per month.
-- Chain: Trade Supervisor → SIC → Owner. Any level can reject + payment hold.

CREATE TABLE IF NOT EXISTS gtv_registrations (
  id                BIGSERIAL PRIMARY KEY,
  worker_id         BIGINT  NOT NULL REFERENCES workers(id)    ON DELETE CASCADE,
  site_id           INTEGER NOT NULL REFERENCES sites(site_id),
  trade             TEXT    NOT NULL,
  planned_gtv_date  DATE    NOT NULL,
  registered_by     UUID    NOT NULL REFERENCES app_users(user_id),
  registered_at     TIMESTAMPTZ DEFAULT NOW(),

  status TEXT NOT NULL DEFAULT 'pending_supervisor'
    CHECK (status IN ('pending_supervisor','pending_sic','pending_owner','approved','rejected')),

  supervisor_id     UUID REFERENCES app_users(user_id),
  supervisor_action TEXT CHECK (supervisor_action IN ('approved','rejected',NULL)),
  supervisor_note   TEXT,
  supervisor_at     TIMESTAMPTZ,

  sic_id     UUID REFERENCES app_users(user_id),
  sic_action TEXT CHECK (sic_action IN ('approved','rejected',NULL)),
  sic_note   TEXT,
  sic_at     TIMESTAMPTZ,

  owner_id     UUID REFERENCES app_users(user_id),
  owner_action TEXT CHECK (owner_action IN ('approved','rejected',NULL)),
  owner_note   TEXT,
  owner_at     TIMESTAMPTZ,

  rejection_reason TEXT,
  payment_hold     BOOLEAN NOT NULL DEFAULT FALSE,
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE gtv_registrations DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_gtvreg_worker  ON gtv_registrations(worker_id);
CREATE INDEX IF NOT EXISTS idx_gtvreg_site    ON gtv_registrations(site_id);
CREATE INDEX IF NOT EXISTS idx_gtvreg_status  ON gtv_registrations(status);
CREATE INDEX IF NOT EXISTS idx_gtvreg_trade   ON gtv_registrations(trade);
CREATE INDEX IF NOT EXISTS idx_gtvreg_planned ON gtv_registrations(planned_gtv_date);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 13 — WALLET TRANSACTIONS
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id            SERIAL PRIMARY KEY,
  wallet_id     INT  REFERENCES cash_wallets(wallet_id) ON DELETE CASCADE,
  from_user_id  UUID REFERENCES app_users(user_id),
  to_user_id    UUID REFERENCES app_users(user_id),
  amount        NUMERIC NOT NULL,
  note          TEXT,
  txn_date      DATE DEFAULT CURRENT_DATE,
  created_by    UUID REFERENCES app_users(user_id),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE wallet_transactions DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_wallet_txn ON wallet_transactions(wallet_id);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 14 — APPROVALS TABLE
-- ───────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS approvals (
  id              SERIAL PRIMARY KEY,
  approval_type   TEXT NOT NULL,  -- 'worker_transfer'|'material_debit'
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','rejected')),
  raised_by       UUID REFERENCES app_users(user_id),
  raised_at       TIMESTAMPTZ DEFAULT NOW(),
  site_id         INT  REFERENCES sites(site_id),
  worker_id       INT  REFERENCES workers(id),
  payload         JSONB,
  resolved_by     UUID REFERENCES app_users(user_id),
  resolved_at     TIMESTAMPTZ,
  resolution_note TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE approvals DISABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_approvals_status ON approvals(status);
CREATE INDEX IF NOT EXISTS idx_approvals_site   ON approvals(site_id);
CREATE INDEX IF NOT EXISTS idx_approvals_worker ON approvals(worker_id);


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 15 — POLICY: CAN_APPROVE + TRADE SUPERVISOR ROLES
-- ───────────────────────────────────────────────────────────────────────────

ALTER TABLE policy_permissions ADD COLUMN IF NOT EXISTS can_approve BOOLEAN DEFAULT FALSE;

INSERT INTO policy_master (policy_name, role_type, description)
VALUES
  ('Carpenter Supervisor Policy', 'Carpenter Supervisor',
   'L1 GTV approver for Carpenter. Haajri scoped to Carpenter workers only.'),
  ('Fitter Supervisor Policy',    'Fitter Supervisor',
   'L1 GTV approver for Fitter. Haajri scoped to Fitter workers only.'),
  ('Labour Supervisor Policy',    'Labour Supervisor',
   'L1 GTV approver for M/C, BRM, PLM combined.')
ON CONFLICT (role_type) DO NOTHING;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 16 — DEFAULT POLICY PERMISSIONS
-- ───────────────────────────────────────────────────────────────────────────

-- can_approve for SIC/Admin/Owner
UPDATE policy_permissions pp
SET can_approve = TRUE
FROM policy_master pm
WHERE pp.policy_id = pm.policy_id
  AND pm.role_type IN ('SIC','Admin','Owner');

-- Attendance as separate module (split from DPR — Engineer gets DPR but NOT Attendance)
INSERT INTO policy_permissions
  (policy_id, module, can_view, can_add, can_edit, can_delete, can_approve, can_export, can_print)
SELECT pm.policy_id, 'Attendance', TRUE,
  CASE WHEN pm.role_type IN (
    'SIC','Admin','Owner','Storekeeper','Supervisor',
    'Carpenter Supervisor','Fitter Supervisor','Labour Supervisor'
  ) THEN TRUE ELSE FALSE END,
  CASE WHEN pm.role_type IN (
    'SIC','Admin','Owner','Storekeeper','Supervisor',
    'Carpenter Supervisor','Fitter Supervisor','Labour Supervisor'
  ) THEN TRUE ELSE FALSE END,
  FALSE,
  CASE WHEN pm.role_type IN ('SIC','Admin','Owner') THEN TRUE ELSE FALSE END,
  CASE WHEN pm.role_type IN ('SIC','Admin','Owner') THEN TRUE ELSE FALSE END,
  CASE WHEN pm.role_type IN ('SIC','Admin','Owner','Storekeeper') THEN TRUE ELSE FALSE END
FROM policy_master pm
ON CONFLICT (policy_id, module) DO NOTHING;

-- Labour view+edit for Trade Supervisors
INSERT INTO policy_permissions (policy_id, module, can_view, can_add, can_edit, can_delete)
SELECT pm.policy_id, 'Labour', TRUE, TRUE, TRUE, FALSE
FROM policy_master pm
WHERE pm.role_type IN ('Carpenter Supervisor','Fitter Supervisor','Labour Supervisor')
ON CONFLICT (policy_id, module) DO NOTHING;

-- Storekeeper: can mark and edit attendance
UPDATE policy_permissions pp
SET can_view = TRUE, can_add = TRUE, can_edit = TRUE
FROM policy_master pm
WHERE pp.policy_id = pm.policy_id
  AND pm.role_type = 'Storekeeper'
  AND pp.module = 'Attendance';

-- Engineer: explicitly NO attendance
UPDATE policy_permissions pp
SET can_view = FALSE, can_add = FALSE, can_edit = FALSE
FROM policy_master pm
WHERE pp.policy_id = pm.policy_id
  AND pm.role_type = 'Engineer'
  AND pp.module = 'Attendance';


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 17 — WORKER STATUS FIX (post-migration)
-- ───────────────────────────────────────────────────────────────────────────
-- Batch-migrated workers defaulted to 'Left'. Fix Active for workers with site.

UPDATE workers
SET status = 'Active'
WHERE current_site_id IS NOT NULL
  AND status = 'Left'
  AND is_active = TRUE;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 18 — INDEXES FOR PAYROLL (Phase 2 ready)
-- ───────────────────────────────────────────────────────────────────────────
-- gtv_last_working_date: set by Mark GTV flow (last confirmed Present record).
-- Payroll uses this as the wage calculation boundary for GTV workers.

CREATE INDEX IF NOT EXISTS idx_workers_gtv_last ON workers(gtv_last_working_date)
  WHERE gtv_last_working_date IS NOT NULL;


-- ───────────────────────────────────────────────────────────────────────────
-- SECTION 19 — VERIFICATION
-- ───────────────────────────────────────────────────────────────────────────

SELECT 'TABLE COUNTS' AS check_type, '' AS detail, 0 AS value
UNION ALL SELECT 'workers',        '', COUNT(*)::int FROM workers
UNION ALL SELECT 'buildings',      '', COUNT(*)::int FROM buildings
UNION ALL SELECT 'worker_ppe',     '', COUNT(*)::int FROM worker_ppe
UNION ALL SELECT 'worker_history', '', COUNT(*)::int FROM worker_history
UNION ALL SELECT 'att_sessions',   '', COUNT(*)::int FROM attendance_sessions
UNION ALL SELECT 'att_records',    '', COUNT(*)::int FROM attendance_records
UNION ALL SELECT 'user_sites',     '', COUNT(*)::int FROM user_sites
UNION ALL SELECT 'gtv_registrations', '', COUNT(*)::int FROM gtv_registrations
UNION ALL SELECT 'approvals',      '', COUNT(*)::int FROM approvals;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'workers'
  AND column_name IN (
    'entry_status','gtv_promise_date','gtv_last_working_date',
    'relative_mobile','ref_worker_id','worker_photo_url',
    'father_name','building_id','advance_paid'
  )
ORDER BY column_name;

SELECT status, COUNT(*) FROM workers GROUP BY status ORDER BY status;

SELECT role_type FROM policy_master
WHERE role_type IN ('Carpenter Supervisor','Fitter Supervisor','Labour Supervisor');

SELECT 'SiteOS V3.4 Master Patch complete' AS result;
