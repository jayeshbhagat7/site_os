-- ═══════════════════════════════════════════════════════════════════════════
-- SITEOS — DATABASE PERFORMANCE FIX
-- Fixes for: Statement timeouts, Auth failures, Missing indexes
-- 
-- Based on Supabase Usage Report:
--   - ERROR: canceling statement due to statement timeout
--   - HTTP 521/522 on /auth/v1/token and /rest/v1/ endpoints
--   - PostgREST query timeouts via authenticator role
--
-- SAFE TO RE-RUN: All statements use IF NOT EXISTS / CREATE OR REPLACE.
-- RUN THIS IN: Supabase Dashboard → SQL Editor → New Query → Paste → Run
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: CRITICAL — LOGIN & AUTH PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: Every login does: SELECT * FROM app_users WHERE auth_id = ?
-- Without an index, this is a full table scan on every token refresh.
-- This directly causes the /auth/v1/token 521/522 errors.

CREATE INDEX IF NOT EXISTS idx_app_users_auth_id
  ON app_users(auth_id);

-- Also used on login: policy_master lookup by role_type
CREATE INDEX IF NOT EXISTS idx_policy_master_role_type
  ON policy_master(role_type);

-- policy_permissions lookup by policy_id (used on every login to load perms)
CREATE INDEX IF NOT EXISTS idx_policy_permissions_policy_id
  ON policy_permissions(policy_id);

-- user_policy_overrides lookup by user_id (loaded on every login)
CREATE INDEX IF NOT EXISTS idx_user_policy_overrides_user_id
  ON user_policy_overrides(user_id);

-- app_users filtered by is_active (dashboard count + user list)
CREATE INDEX IF NOT EXISTS idx_app_users_is_active
  ON app_users(is_active)
  WHERE is_active = TRUE;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: WORKERS TABLE — MOST QUERIED TABLE
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: WorkerMaster does fetchAll(workers.select("*,sites(site_name)"))
-- which pulls ALL workers (500+) with a join. Then filters client-side by
-- status and current_site_id. The DB should do this filtering.

-- Composite index: status + current_site_id (most common filter pattern)
CREATE INDEX IF NOT EXISTS idx_workers_status_site
  ON workers(status, current_site_id);

-- Composite index: current_site_id + status + is_active (attendance page)
CREATE INDEX IF NOT EXISTS idx_workers_site_status_active
  ON workers(current_site_id, status, is_active)
  WHERE is_active = TRUE;

-- Partial index: Active workers only (dashboard count, attendance)
CREATE INDEX IF NOT EXISTS idx_workers_active
  ON workers(current_site_id, worker_name)
  WHERE status = 'Active';

-- Partial index: GTV workers only (dashboard, GTV expiry check)
CREATE INDEX IF NOT EXISTS idx_workers_gtv
  ON workers(gtv_date)
  WHERE status = 'GTV';

-- Partial index: Left workers (GTV/Left combined view)
CREATE INDEX IF NOT EXISTS idx_workers_left
  ON workers(worker_name)
  WHERE status = 'Left';

-- Workers ordered by worker_name (used in almost every worker list)
CREATE INDEX IF NOT EXISTS idx_workers_name
  ON workers(worker_name);

-- Workers ordered by worker_code (used in GTV/Left sorted view)
CREATE INDEX IF NOT EXISTS idx_workers_code_text
  ON workers(worker_code);

-- Workers by entry_status (pending approval notifications)
CREATE INDEX IF NOT EXISTS idx_workers_entry_status
  ON workers(entry_status)
  WHERE entry_status = 'pending_approval';

-- Workers created_at descending (New Registration list)
CREATE INDEX IF NOT EXISTS idx_workers_created_desc
  ON workers(created_at DESC)
  WHERE is_active = TRUE;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: ATTENDANCE — SECOND MOST QUERIED
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: Payroll calculates wages by fetching all attendance_records
-- for a date range, filtered by session_id IN (...) and is_present=true.
-- Without composite indexes this causes sequential scans on large tables.

-- Composite: session_id + is_present (payroll wage calculation)
CREATE INDEX IF NOT EXISTS idx_att_records_session_present
  ON attendance_records(session_id, is_present)
  WHERE is_present = TRUE;

-- Composite: worker_id + is_present (GTV mark flow — check open sessions)
CREATE INDEX IF NOT EXISTS idx_att_records_worker_present
  ON attendance_records(worker_id, is_present);

-- Composite: session_id + worker_id (unique lookup per attendance mark)
CREATE INDEX IF NOT EXISTS idx_att_records_session_worker
  ON attendance_records(session_id, worker_id);

-- Sessions: composite site + date (used on every attendance page load)
CREATE INDEX IF NOT EXISTS idx_att_sessions_site_date
  ON attendance_sessions(site_id, att_date);

-- Sessions: date range queries for payroll
CREATE INDEX IF NOT EXISTS idx_att_sessions_date_site
  ON attendance_sessions(att_date, site_id);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: APPROVALS — FILTERED BY STATUS + ROLE
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: Dashboard loads pending approvals count. Approvals page filters
-- by status AND approver_role. Missing approver_role index.

-- Add approver_role column index (filtered by Office role on every page load)
CREATE INDEX IF NOT EXISTS idx_approvals_approver_role
  ON approvals(approver_role);

-- Composite: status + approver_role (most common approval query)
CREATE INDEX IF NOT EXISTS idx_approvals_status_role
  ON approvals(status, approver_role)
  WHERE status = 'pending';

-- Composite: status + site_id (SIC approval filtering)
CREATE INDEX IF NOT EXISTS idx_approvals_status_site
  ON approvals(status, site_id)
  WHERE status = 'pending';

-- Approvals ordered by created_at desc (approval list page)
CREATE INDEX IF NOT EXISTS idx_approvals_created_desc
  ON approvals(created_at DESC);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: MATERIALS & STORES — DASHBOARD QUERIES
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: Dashboard fetches all active materials to check MOQ.

-- Materials: is_active filter (used on every dashboard load)
CREATE INDEX IF NOT EXISTS idx_materials_active
  ON materials(is_active)
  WHERE is_active = TRUE;

-- Materials: below MOQ partial index (dashboard "Below MOQ" stat)
CREATE INDEX IF NOT EXISTS idx_materials_below_moq
  ON materials(material_id)
  WHERE is_active = TRUE AND moq > 0;

-- Stores: is_active (dashboard count)
CREATE INDEX IF NOT EXISTS idx_stores_active
  ON stores(is_active)
  WHERE is_active = TRUE;

-- Stores: site_id + is_active (store master grouped view)
CREATE INDEX IF NOT EXISTS idx_stores_site_active
  ON stores(site_id, is_active);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: SITES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

-- Sites: is_active (used in almost every dropdown and filter)
CREATE INDEX IF NOT EXISTS idx_sites_active
  ON sites(is_active, site_name)
  WHERE is_active = TRUE;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7: GTV REGISTRATIONS — 3-LEVEL APPROVAL CHAIN
-- ═══════════════════════════════════════════════════════════════════════════

-- Composite: status + trade (supervisor approval filtering)
CREATE INDEX IF NOT EXISTS idx_gtvreg_status_trade
  ON gtv_registrations(status, trade);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8: WORKER HISTORY & PPE — SECONDARY TABLES
-- ═══════════════════════════════════════════════════════════════════════════

-- Worker history: composite worker + event_date descending
CREATE INDEX IF NOT EXISTS idx_worker_history_worker_date
  ON worker_history(worker_id, event_date DESC);

-- Worker PPE: site_id (PPE report per site)
CREATE INDEX IF NOT EXISTS idx_worker_ppe_site
  ON worker_ppe(site_id);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 9: USER_SITES — LOADED ON EVERY LOGIN
-- ═══════════════════════════════════════════════════════════════════════════

-- Already has indexes from master patch, but add composite for login query
CREATE INDEX IF NOT EXISTS idx_user_sites_user_site
  ON user_sites(user_id, site_id);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 10: STATEMENT TIMEOUT CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: Default PostgREST statement_timeout may be too low (3s).
-- For complex queries with JOINs across workers+sites, increase to 10s.
-- NOTE: This applies to the 'authenticator' role used by PostgREST/Supabase.
-- You may need to set this in Supabase Dashboard → Database → Settings.

-- Increase timeout for the anon and authenticated roles
ALTER ROLE authenticator SET statement_timeout = '10s';
ALTER ROLE anon SET statement_timeout = '10s';
ALTER ROLE authenticated SET statement_timeout = '10s';


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 11: VACUUM & ANALYZE (run after creating indexes)
-- ═══════════════════════════════════════════════════════════════════════════
-- Forces PostgreSQL to update its query planner statistics so it uses
-- the new indexes immediately rather than waiting for auto-vacuum.

ANALYZE workers;
ANALYZE attendance_records;
ANALYZE attendance_sessions;
ANALYZE approvals;
ANALYZE app_users;
ANALYZE materials;
ANALYZE stores;
ANALYZE sites;
ANALYZE policy_master;
ANALYZE policy_permissions;
ANALYZE user_policy_overrides;
ANALYZE user_sites;
ANALYZE gtv_registrations;
ANALYZE worker_history;
ANALYZE worker_ppe;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 12: VERIFY INDEXES CREATED
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_indexes
JOIN pg_class ON pg_class.relname = indexname
WHERE schemaname = 'public'
  AND tablename IN (
    'workers','attendance_records','attendance_sessions',
    'approvals','app_users','materials','stores','sites',
    'policy_master','policy_permissions','user_policy_overrides',
    'user_sites','gtv_registrations','worker_history','worker_ppe'
  )
ORDER BY tablename, indexname;

SELECT 'SiteOS Performance Fix applied successfully' AS result;
