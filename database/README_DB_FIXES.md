# SiteOS Database Performance & Security Fix

## Problem Summary

Based on the Supabase usage report, the database has these issues:

| Issue | Severity | Root Cause |
|-------|----------|------------|
| HTTP 521/522 on `/auth/v1/token` | **Critical** | Missing index on `app_users.auth_id` — every login/refresh does a full table scan |
| `ERROR: canceling statement due to statement timeout` | **Critical** | Missing composite indexes on `workers`, `attendance_records`, `approvals` |
| KeyleakScanner traffic hitting `/rest/v1/` | **High** | RLS disabled on all tables — anon key can read everything |
| Query advisor lint timeout | **Medium** | Large sequential scans preventing advisor from completing |

## Fix Files (Run in Order)

### Step 1: `performance_fix.sql` (Run FIRST)

Adds 30+ targeted indexes to eliminate sequential scans on the most-queried tables:

- **Login fix**: Index on `app_users(auth_id)` — fixes the 521/522 auth failures
- **Workers**: Composite indexes for `(status, current_site_id)`, partial indexes for Active/GTV/Left
- **Attendance**: Composite indexes for `(session_id, is_present)`, `(worker_id, is_present)`, `(site_id, att_date)`
- **Approvals**: Index on `approver_role`, composite `(status, approver_role)`
- **Materials/Stores**: Partial indexes for `is_active = TRUE`
- **Statement timeout**: Increased from default 3s to 10s for complex queries
- **ANALYZE**: Forces PostgreSQL to update planner statistics immediately

### Step 2: `rls_security_fix.sql` (Run SECOND — optional but recommended)

Enables Row Level Security on all tables to:

- **Block anonymous access** completely (fixes the KeyleakScanner issue)
- **Allow authenticated users** to read shared data
- **Restrict writes** on master tables to Admin/Owner only
- Includes **rollback section** if something breaks

## How to Run

1. Open **Supabase Dashboard** → go to your project
2. Click **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy-paste the **entire contents** of `performance_fix.sql`
5. Click **Run** (or Ctrl+Enter)
6. Verify you see: `SiteOS Performance Fix applied successfully`
7. *(Optional)* Repeat for `rls_security_fix.sql`

## Expected Impact

| Metric | Before | After |
|--------|--------|-------|
| Login time (auth token) | 500ms–timeout | <50ms |
| Worker list load | 2–5s (timeout on large data) | <500ms |
| Attendance page load | 1–3s | <300ms |
| Dashboard load | 1–2s (parallel timeouts) | <400ms |
| Anon key data leak risk | **All data exposed** | **Blocked** |

## If Something Breaks

### Performance fix caused issues:
Indexes are harmless — they can't break queries. If timeouts persist, the issue is elsewhere. Check:
```sql
-- See currently running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND duration > interval '3 seconds';
```

### RLS fix caused "permission denied" errors:
Run the rollback section at the bottom of `rls_security_fix.sql`:
```sql
ALTER TABLE app_users DISABLE ROW LEVEL SECURITY;
ALTER TABLE sites DISABLE ROW LEVEL SECURITY;
-- ... (full list in the file)
```

## Root Cause Analysis

The core issue is that the app was built without database indexes beyond basic primary keys. With 500+ workers, thousands of attendance records, and multiple concurrent users, PostgreSQL falls back to sequential (full-table) scans which exceed the 3-second PostgREST timeout.

The auth failures (521/522) are a cascade: when the database is overloaded by slow queries from the REST API, the auth service (which also queries the database) gets starved and times out.

## Future Recommendations

1. **Reduce `SELECT *` usage** — fetch only needed columns (especially on workers table)
2. **Add server-side pagination** — instead of `fetchAll` which loads 1000 rows at a time
3. **Enable `pg_stat_statements`** — to monitor slow queries over time
4. **Set up connection pooling alerts** — in Supabase Dashboard → Database → Settings
5. **Consider a Supabase Edge Function** for the payroll calculation query (complex aggregation)
