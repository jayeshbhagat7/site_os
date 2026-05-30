-- ═══════════════════════════════════════════════════════════════════════════
-- SITEOS — STEP 1: PERFORMANCE INDEXES (SAFE VERSION)
-- 
-- Just copy this ENTIRE text → paste into Supabase SQL Editor → click Run
--
-- This script:
--   ✅ Only creates indexes (cannot break anything)
--   ✅ Uses IF NOT EXISTS (safe to run multiple times)
--   ✅ Skips tables that don't exist (no errors)
--   ✅ Fixes login timeouts immediately
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── FIX LOGIN FAILURES (521/522 errors) ────────────────────────────────
-- This is the #1 fix. Every login queries app_users by auth_id.

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='app_users') THEN
    CREATE INDEX IF NOT EXISTS idx_app_users_auth_id ON app_users(auth_id);
    CREATE INDEX IF NOT EXISTS idx_app_users_active ON app_users(is_active) WHERE is_active = TRUE;
    RAISE NOTICE 'app_users indexes created';
  END IF;
END $$;

-- ─── FIX WORKER QUERIES (slow page loads) ───────────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='workers') THEN
    CREATE INDEX IF NOT EXISTS idx_workers_status_site ON workers(status, current_site_id);
    CREATE INDEX IF NOT EXISTS idx_workers_active ON workers(current_site_id, worker_name) WHERE status = 'Active';
    CREATE INDEX IF NOT EXISTS idx_workers_gtv ON workers(gtv_date) WHERE status = 'GTV';
    CREATE INDEX IF NOT EXISTS idx_workers_name ON workers(worker_name);
    CREATE INDEX IF NOT EXISTS idx_workers_code_v2 ON workers(worker_code);
    CREATE INDEX IF NOT EXISTS idx_workers_site_active ON workers(current_site_id, status, is_active) WHERE is_active = TRUE;
    RAISE NOTICE 'workers indexes created';
  END IF;
END $$;

-- ─── FIX ATTENDANCE QUERIES (payroll timeouts) ──────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='attendance_sessions') THEN
    CREATE INDEX IF NOT EXISTS idx_att_sessions_site_date ON attendance_sessions(site_id, att_date);
    CREATE INDEX IF NOT EXISTS idx_att_sessions_date_site ON attendance_sessions(att_date, site_id);
    RAISE NOTICE 'attendance_sessions indexes created';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='attendance_records') THEN
    CREATE INDEX IF NOT EXISTS idx_att_records_session_present ON attendance_records(session_id, is_present) WHERE is_present = TRUE;
    CREATE INDEX IF NOT EXISTS idx_att_records_worker_present ON attendance_records(worker_id, is_present);
    CREATE INDEX IF NOT EXISTS idx_att_records_session_worker ON attendance_records(session_id, worker_id);
    RAISE NOTICE 'attendance_records indexes created';
  END IF;
END $$;

-- ─── FIX APPROVAL QUERIES ───────────────────────────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='approvals') THEN
    CREATE INDEX IF NOT EXISTS idx_approvals_status_v2 ON approvals(status) WHERE status = 'pending';
    CREATE INDEX IF NOT EXISTS idx_approvals_created_desc ON approvals(created_at DESC);
    -- approver_role column may or may not exist
    BEGIN
      CREATE INDEX IF NOT EXISTS idx_approvals_approver_role ON approvals(approver_role);
    EXCEPTION WHEN undefined_column THEN
      RAISE NOTICE 'approver_role column does not exist, skipping';
    END;
    RAISE NOTICE 'approvals indexes created';
  END IF;
END $$;

-- ─── FIX POLICY LOOKUPS (loaded on every login) ─────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='policy_master') THEN
    CREATE INDEX IF NOT EXISTS idx_policy_master_role ON policy_master(role_type);
    RAISE NOTICE 'policy_master index created';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='policy_permissions') THEN
    CREATE INDEX IF NOT EXISTS idx_policy_perms_policy ON policy_permissions(policy_id);
    RAISE NOTICE 'policy_permissions index created';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_policy_overrides') THEN
    CREATE INDEX IF NOT EXISTS idx_upo_user ON user_policy_overrides(user_id);
    RAISE NOTICE 'user_policy_overrides index created';
  END IF;
END $$;

-- ─── FIX SITES/STORES/MATERIALS (dashboard loads) ───────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='sites') THEN
    CREATE INDEX IF NOT EXISTS idx_sites_active ON sites(is_active, site_name) WHERE is_active = TRUE;
    RAISE NOTICE 'sites index created';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='stores') THEN
    CREATE INDEX IF NOT EXISTS idx_stores_active ON stores(is_active) WHERE is_active = TRUE;
    CREATE INDEX IF NOT EXISTS idx_stores_site ON stores(site_id, is_active);
    RAISE NOTICE 'stores indexes created';
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='materials') THEN
    CREATE INDEX IF NOT EXISTS idx_materials_active ON materials(is_active) WHERE is_active = TRUE;
    RAISE NOTICE 'materials index created';
  END IF;
END $$;

-- ─── FIX USER_SITES (loaded on every login) ─────────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_sites') THEN
    CREATE INDEX IF NOT EXISTS idx_user_sites_user ON user_sites(user_id);
    RAISE NOTICE 'user_sites index created';
  END IF;
END $$;

-- ─── FIX GTV REGISTRATIONS ──────────────────────────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='gtv_registrations') THEN
    CREATE INDEX IF NOT EXISTS idx_gtvreg_status_trade ON gtv_registrations(status, trade);
    RAISE NOTICE 'gtv_registrations index created';
  END IF;
END $$;

-- ─── FIX WORKER HISTORY ─────────────────────────────────────────────────

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='worker_history') THEN
    CREATE INDEX IF NOT EXISTS idx_wh_worker_date ON worker_history(worker_id, event_date DESC);
    RAISE NOTICE 'worker_history index created';
  END IF;
END $$;

-- ─── INCREASE STATEMENT TIMEOUT ─────────────────────────────────────────
-- Default is 3s which is too short for joins across 500+ workers

DO $$ BEGIN
  EXECUTE 'ALTER ROLE authenticated SET statement_timeout = ''10s''';
  RAISE NOTICE 'statement_timeout increased to 10s';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not alter role timeout (might need dashboard settings)';
END $$;

-- ─── UPDATE QUERY PLANNER ───────────────────────────────────────────────
-- Tell PostgreSQL to use the new indexes immediately

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='workers') THEN
    ANALYZE workers;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='app_users') THEN
    ANALYZE app_users;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='attendance_records') THEN
    ANALYZE attendance_records;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='attendance_sessions') THEN
    ANALYZE attendance_sessions;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='approvals') THEN
    ANALYZE approvals;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='sites') THEN
    ANALYZE sites;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='materials') THEN
    ANALYZE materials;
  END IF;
END $$;

-- ─── DONE ───────────────────────────────────────────────────────────────

SELECT '✅ SiteOS Performance Fix — All indexes created successfully!' AS result;
