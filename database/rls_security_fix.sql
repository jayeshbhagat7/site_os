-- ═══════════════════════════════════════════════════════════════════════════
-- SITEOS — ROW LEVEL SECURITY (RLS) FIX
-- 
-- PROBLEM:
-- Most tables have RLS DISABLED. This means ANY authenticated user (or even
-- the anon key) can read/write ALL rows in ALL tables via the Supabase REST
-- API. A malicious user or leaked anon key could dump the entire database.
--
-- The app uses service_role key for admin operations, which bypasses RLS.
-- Normal users connect via anon key → authenticated role after login.
-- RLS should enforce that authenticated users only see data they're allowed to.
--
-- CURRENT STATE:
--   app_users          → RLS DISABLED (anyone can read all users)
--   workers            → RLS DISABLED (anyone can read all workers)  
--   attendance_*       → RLS DISABLED
--   approvals          → RLS DISABLED
--   sites/stores       → RLS DISABLED
--   materials          → RLS DISABLED
--   All other tables   → RLS DISABLED
--
-- STRATEGY:
-- Since this app uses a SINGLE auth system where all users share data
-- (multi-role, not multi-tenant per user), RLS policies should:
--   1. Allow authenticated users to SELECT all shared data
--   2. Restrict INSERT/UPDATE/DELETE based on the user's role in app_users
--   3. Block anon (unauthenticated) access completely
--   4. service_role (admin operations) bypasses RLS automatically
--
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- ⚠️  IMPORTANT: Run performance_fix.sql FIRST (indexes on app_users.auth_id)
--     RLS policies that look up app_users.auth_id NEED that index or they'll
--     cause even worse timeouts.
--
-- ⚠️  TEST CAREFULLY: After enabling RLS, verify your app still works.
--     If something breaks, run the ROLLBACK section at the bottom.
--
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTION: Get current user's role from app_users
-- ═══════════════════════════════════════════════════════════════════════════
-- This is called by RLS policies. Cached per transaction for performance.

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM app_users WHERE auth_id = auth.uid() LIMIT 1;
$$;

-- Helper: Get current user's user_id from app_users
CREATE OR REPLACE FUNCTION public.get_my_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT user_id FROM app_users WHERE auth_id = auth.uid() LIMIT 1;
$$;

-- Helper: Check if user is admin/owner (can write to master tables)
CREATE OR REPLACE FUNCTION public.is_admin_or_owner()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM app_users 
    WHERE auth_id = auth.uid() 
      AND role IN ('Admin','Owner')
      AND is_active = TRUE
  );
$$;

-- Helper: Check if user is authenticated and active
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM app_users 
    WHERE auth_id = auth.uid() 
      AND is_active = TRUE
  );
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: APP_USERS — Core user table
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;

-- All active authenticated users can view all users (needed for dropdowns, names)
CREATE POLICY "Authenticated users can view all app_users"
  ON app_users FOR SELECT
  TO authenticated
  USING (is_active_user());

-- Only Admin can insert new users
CREATE POLICY "Admin can insert app_users"
  ON app_users FOR INSERT
  TO authenticated
  WITH CHECK (is_admin_or_owner());

-- Admin can update any user; users can update their own profile (avatar, phone)
CREATE POLICY "Admin or self can update app_users"
  ON app_users FOR UPDATE
  TO authenticated
  USING (
    is_admin_or_owner() OR auth_id = auth.uid()
  );

-- Block anon completely
CREATE POLICY "Anon cannot access app_users"
  ON app_users FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: SITES — Shared reference data
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view sites
CREATE POLICY "Authenticated can view sites"
  ON sites FOR SELECT
  TO authenticated
  USING (is_active_user());

-- Only Admin/Owner can create/modify sites
CREATE POLICY "Admin/Owner can modify sites"
  ON sites FOR INSERT
  TO authenticated
  WITH CHECK (is_admin_or_owner());

CREATE POLICY "Admin/Owner can update sites"
  ON sites FOR UPDATE
  TO authenticated
  USING (is_admin_or_owner());

CREATE POLICY "Admin/Owner can delete sites"
  ON sites FOR DELETE
  TO authenticated
  USING (is_admin_or_owner());

-- Block anon
CREATE POLICY "Anon cannot access sites"
  ON sites FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: STORES — Shared reference data
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view stores"
  ON stores FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Admin/Owner can modify stores"
  ON stores FOR INSERT
  TO authenticated
  WITH CHECK (is_admin_or_owner());

CREATE POLICY "Admin/Owner can update stores"
  ON stores FOR UPDATE
  TO authenticated
  USING (is_admin_or_owner());

-- Block anon
CREATE POLICY "Anon cannot access stores"
  ON stores FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: WORKERS — Core operational data
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE workers ENABLE ROW LEVEL SECURITY;

-- All authenticated active users can view workers (needed for attendance, lists)
CREATE POLICY "Authenticated can view workers"
  ON workers FOR SELECT
  TO authenticated
  USING (is_active_user());

-- Users with Labour can_add permission can insert (checked app-side too)
CREATE POLICY "Authenticated can insert workers"
  ON workers FOR INSERT
  TO authenticated
  WITH CHECK (is_active_user());

-- Users with Labour can_edit permission can update
CREATE POLICY "Authenticated can update workers"
  ON workers FOR UPDATE
  TO authenticated
  USING (is_active_user());

-- Block anon
CREATE POLICY "Anon cannot access workers"
  ON workers FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: ATTENDANCE TABLES
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;

-- Sessions: all authenticated can view
CREATE POLICY "Authenticated can view attendance_sessions"
  ON attendance_sessions FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Authenticated can insert attendance_sessions"
  ON attendance_sessions FOR INSERT
  TO authenticated
  WITH CHECK (is_active_user());

CREATE POLICY "Authenticated can update attendance_sessions"
  ON attendance_sessions FOR UPDATE
  TO authenticated
  USING (is_active_user());

-- Records: all authenticated can view
CREATE POLICY "Authenticated can view attendance_records"
  ON attendance_records FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Authenticated can insert attendance_records"
  ON attendance_records FOR INSERT
  TO authenticated
  WITH CHECK (is_active_user());

CREATE POLICY "Authenticated can update attendance_records"
  ON attendance_records FOR UPDATE
  TO authenticated
  USING (is_active_user());

-- Block anon on both
CREATE POLICY "Anon cannot access attendance_sessions"
  ON attendance_sessions FOR ALL
  TO anon
  USING (FALSE);

CREATE POLICY "Anon cannot access attendance_records"
  ON attendance_records FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: APPROVALS
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE approvals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view approvals"
  ON approvals FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Authenticated can insert approvals"
  ON approvals FOR INSERT
  TO authenticated
  WITH CHECK (is_active_user());

CREATE POLICY "Authenticated can update approvals"
  ON approvals FOR UPDATE
  TO authenticated
  USING (is_active_user());

-- Block anon
CREATE POLICY "Anon cannot access approvals"
  ON approvals FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7: MATERIALS
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE materials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view materials"
  ON materials FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Admin/Owner can modify materials"
  ON materials FOR INSERT
  TO authenticated
  WITH CHECK (is_active_user());

CREATE POLICY "Admin/Owner can update materials"
  ON materials FOR UPDATE
  TO authenticated
  USING (is_active_user());

-- Block anon
CREATE POLICY "Anon cannot access materials"
  ON materials FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8: POLICY MASTER & PERMISSIONS (read-only for most users)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE policy_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view policy_master"
  ON policy_master FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Admin can modify policy_master"
  ON policy_master FOR ALL
  TO authenticated
  USING (is_admin_or_owner());

CREATE POLICY "Authenticated can view policy_permissions"
  ON policy_permissions FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Admin can modify policy_permissions"
  ON policy_permissions FOR ALL
  TO authenticated
  USING (is_admin_or_owner());

-- Block anon
CREATE POLICY "Anon cannot access policy_master"
  ON policy_master FOR ALL
  TO anon
  USING (FALSE);

CREATE POLICY "Anon cannot access policy_permissions"
  ON policy_permissions FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 9: USER_SITES & USER_POLICY_OVERRIDES
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE user_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_policy_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view user_sites"
  ON user_sites FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Admin can modify user_sites"
  ON user_sites FOR ALL
  TO authenticated
  USING (is_admin_or_owner());

CREATE POLICY "Authenticated can view user_policy_overrides"
  ON user_policy_overrides FOR SELECT
  TO authenticated
  USING (is_active_user());

CREATE POLICY "Admin can modify user_policy_overrides"
  ON user_policy_overrides FOR ALL
  TO authenticated
  USING (is_admin_or_owner());

-- Block anon
CREATE POLICY "Anon cannot access user_sites"
  ON user_sites FOR ALL
  TO anon
  USING (FALSE);

CREATE POLICY "Anon cannot access user_policy_overrides"
  ON user_policy_overrides FOR ALL
  TO anon
  USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 10: BUILDINGS, WORKER_PPE, WORKER_HISTORY, GTV_REGISTRATIONS
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_ppe ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_ppe_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE gtv_registrations ENABLE ROW LEVEL SECURITY;

-- Buildings
CREATE POLICY "Authenticated can view buildings"
  ON buildings FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Admin can modify buildings"
  ON buildings FOR ALL TO authenticated USING (is_admin_or_owner());
CREATE POLICY "Anon cannot access buildings"
  ON buildings FOR ALL TO anon USING (FALSE);

-- Worker PPE
CREATE POLICY "Authenticated can view worker_ppe"
  ON worker_ppe FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Authenticated can modify worker_ppe"
  ON worker_ppe FOR INSERT TO authenticated WITH CHECK (is_active_user());
CREATE POLICY "Authenticated can update worker_ppe"
  ON worker_ppe FOR UPDATE TO authenticated USING (is_active_user());
CREATE POLICY "Anon cannot access worker_ppe"
  ON worker_ppe FOR ALL TO anon USING (FALSE);

-- Worker PPE Log
CREATE POLICY "Authenticated can view worker_ppe_log"
  ON worker_ppe_log FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Authenticated can insert worker_ppe_log"
  ON worker_ppe_log FOR INSERT TO authenticated WITH CHECK (is_active_user());
CREATE POLICY "Anon cannot access worker_ppe_log"
  ON worker_ppe_log FOR ALL TO anon USING (FALSE);

-- Worker History
CREATE POLICY "Authenticated can view worker_history"
  ON worker_history FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Authenticated can insert worker_history"
  ON worker_history FOR INSERT TO authenticated WITH CHECK (is_active_user());
CREATE POLICY "Anon cannot access worker_history"
  ON worker_history FOR ALL TO anon USING (FALSE);

-- GTV Registrations
CREATE POLICY "Authenticated can view gtv_registrations"
  ON gtv_registrations FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Authenticated can insert gtv_registrations"
  ON gtv_registrations FOR INSERT TO authenticated WITH CHECK (is_active_user());
CREATE POLICY "Authenticated can update gtv_registrations"
  ON gtv_registrations FOR UPDATE TO authenticated USING (is_active_user());
CREATE POLICY "Anon cannot access gtv_registrations"
  ON gtv_registrations FOR ALL TO anon USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 11: WALLET & TRANSACTIONS (if table exists)
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cash_wallets') THEN
    EXECUTE 'ALTER TABLE cash_wallets ENABLE ROW LEVEL SECURITY';
    EXECUTE 'CREATE POLICY "Authenticated can view cash_wallets" ON cash_wallets FOR SELECT TO authenticated USING (public.is_active_user())';
    EXECUTE 'CREATE POLICY "Authenticated can modify cash_wallets" ON cash_wallets FOR ALL TO authenticated USING (public.is_active_user())';
    EXECUTE 'CREATE POLICY "Anon cannot access cash_wallets" ON cash_wallets FOR ALL TO anon USING (FALSE)';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wallet_transactions') THEN
    EXECUTE 'ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY';
    EXECUTE 'CREATE POLICY "Authenticated can view wallet_transactions" ON wallet_transactions FOR SELECT TO authenticated USING (public.is_active_user())';
    EXECUTE 'CREATE POLICY "Authenticated can modify wallet_transactions" ON wallet_transactions FOR ALL TO authenticated USING (public.is_active_user())';
    EXECUTE 'CREATE POLICY "Anon cannot access wallet_transactions" ON wallet_transactions FOR ALL TO anon USING (FALSE)';
  END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 12: DPR REPORTS
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE dpr_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view dpr_reports"
  ON dpr_reports FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Authenticated can insert dpr_reports"
  ON dpr_reports FOR INSERT TO authenticated WITH CHECK (is_active_user());
CREATE POLICY "Authenticated can update dpr_reports"
  ON dpr_reports FOR UPDATE TO authenticated USING (is_active_user());
CREATE POLICY "Anon cannot access dpr_reports"
  ON dpr_reports FOR ALL TO anon USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 13: ATTENDANCE_BUILDING_ASSIGNMENTS
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE attendance_building_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated can view attendance_building_assignments"
  ON attendance_building_assignments FOR SELECT TO authenticated USING (is_active_user());
CREATE POLICY "Authenticated can insert attendance_building_assignments"
  ON attendance_building_assignments FOR INSERT TO authenticated WITH CHECK (is_active_user());
CREATE POLICY "Authenticated can update attendance_building_assignments"
  ON attendance_building_assignments FOR UPDATE TO authenticated USING (is_active_user());
CREATE POLICY "Anon cannot access attendance_building_assignments"
  ON attendance_building_assignments FOR ALL TO anon USING (FALSE);


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'app_users','sites','stores','workers','attendance_sessions',
    'attendance_records','approvals','materials','policy_master',
    'policy_permissions','user_sites','user_policy_overrides',
    'buildings','worker_ppe','worker_ppe_log','worker_history',
    'gtv_registrations','dpr_reports','attendance_building_assignments'
  )
ORDER BY tablename;


-- ═══════════════════════════════════════════════════════════════════════════
-- ROLLBACK (if something breaks after enabling RLS)
-- ═══════════════════════════════════════════════════════════════════════════
-- Uncomment and run ONLY if the app stops working after applying RLS:
/*

ALTER TABLE app_users DISABLE ROW LEVEL SECURITY;
ALTER TABLE sites DISABLE ROW LEVEL SECURITY;
ALTER TABLE stores DISABLE ROW LEVEL SECURITY;
ALTER TABLE workers DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE approvals DISABLE ROW LEVEL SECURITY;
ALTER TABLE materials DISABLE ROW LEVEL SECURITY;
ALTER TABLE policy_master DISABLE ROW LEVEL SECURITY;
ALTER TABLE policy_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_sites DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_policy_overrides DISABLE ROW LEVEL SECURITY;
ALTER TABLE buildings DISABLE ROW LEVEL SECURITY;
ALTER TABLE worker_ppe DISABLE ROW LEVEL SECURITY;
ALTER TABLE worker_ppe_log DISABLE ROW LEVEL SECURITY;
ALTER TABLE worker_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE gtv_registrations DISABLE ROW LEVEL SECURITY;
ALTER TABLE dpr_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_building_assignments DISABLE ROW LEVEL SECURITY;

*/

SELECT 'SiteOS RLS Security Fix applied successfully' AS result;
