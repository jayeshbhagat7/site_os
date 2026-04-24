# SiteOS — Session Memory
**Umiya Associates · Jayesh Bhagat · Last updated: April 2026**

---

## 1. Project Identity

| Field | Value |
|---|---|
| App file | `siteos_v3_v3.html` (~8889 lines) |
| Architecture | Single-file React + Supabase (Babel in-browser) |
| Supabase project | `nixusvqbslokiexxxtic.supabase.co` |
| RLS status | Disabled on all tables — intentional, will enable at first external user |

---

## 2. Key Users

| Name | Email | Role | Auth UUID |
|---|---|---|---|
| Jayesh Bhagat | jayeshbhagat7@gmail.com | Admin / SIC | `dafd696b-a3c8-4a34-a12d-26851049332a` |
| Milton Sekh | miltonsk556@gmail.com | Storekeeper | `28c5b234-5e68-4543-b527-ce62a4ee64de` |

- **4,149 workers** migrated
- **Active site:** Wadhwa Wise City (`site_id = 1`)

---

## 3. SQL Patches Applied

### V3.4 Master Patch — All 19 sections complete
| Section | What was applied |
|---|---|
| 1 | Workers table — all additional columns |
| 2 | Sites — `job_id` column |
| 3 | `app_users` — role constraint dropped |
| 4 | `buildings` table created |
| 5–6 | `worker_ppe` + `worker_ppe_log` tables |
| 7 | `worker_history` table |
| 8 | `attendance_sessions`, `attendance_records`, `attendance_building_assignments` |
| 9 | `dpr_reports` table |
| 10 | `user_sites` junction table |
| 11 | `user_policy_overrides` table |
| 12 | `gtv_registrations` table |
| 13 | `wallet_transactions` — **fixed:** dropped partial table, recreated correctly |
| 14 | `approvals` — **patched:** added `worker_id`, `resolved_by`, `resolved_at`, `resolution_note` |
| 15–16 | Policy permissions — `can_approve`, trade supervisor roles, Attendance/DPR split |
| 17 | Worker status fix — `Active` restored for migrated workers |
| 18 | `gtv_last_working_date` — **fixed:** column added first, then index created |
| 19 | Verification passed ✓ |

### Security Patch — Complete
- `consent_given BOOLEAN DEFAULT FALSE` added to `workers`
- `consent_date DATE` added to `workers`
- Index on `consent_given` for compliance queries
- Session timeout: implemented in HTML (no SQL needed)

### FK Fix
- `fk_workers_building` validated after cleaning orphaned `building_id` values

---

## 4. Features Added This Session

### Change Email (Admin)
- Button in Edit User SlideOver — "✉ Change Email Address"
- Calls `sbAdmin.auth.admin.updateUserById(auth_id, { email, email_confirm: true })`
- Syncs new email to `app_users` table
- Takes effect immediately — no confirmation email sent

### Bulk Mark Absent (Attendance → Step 1)
- Checkbox column added to AbsentStep table
- Header checkbox = Select All (scoped to filtered present workers)
- Red bulk action bar appears when any rows selected: "Mark X Absent"
- `bulkMarkAbsent()` in parent respects SK lock and session lock guards

### Session Timeout
- 30-minute idle auto-logout in `App()` component
- Resets on: `mousemove`, `mousedown`, `keydown`, `touchstart`, `scroll`, `click`
- Alert shown on expiry, user redirected to login

### DPDP Consent (New Registration — Step 6)
- Checkbox at bottom of Step 6 with full DPDP Act 2023 wording
- Required before final save (draft saves on earlier steps still free)
- `consent_date` auto-set to today when ticked
- Status badge shown in `WorkerViewModal` — green if recorded, amber if not

---

## 5. Bug Fixes This Session

### Silent empty screens — WorkerMaster + LabourEntry + Attendance
- **Cause:** PostgREST FK joins `buildings(building_name)` and `stores(store_name)` silently returned null because FKs were added as `NOT VALID`
- **Fix:** Removed these joins from all worker fetch queries. Store name now resolved from already-loaded `stores` array using `current_store_id` lookup
- **Affected queries:** WorkerMaster `load()`, LabourEntry `load()`, Attendance `loadSession()`

### Workers not loading in Attendance
- **Cause:** All 4,149 migrated workers had `entry_status = 'draft'` from batch migration
- **Fix:** `UPDATE workers SET entry_status = 'active' WHERE status = 'Active' AND is_active = TRUE AND entry_status = 'draft' AND current_site_id IS NOT NULL`

### fetchAll silent failures
- Added `error` logging to `fetchAll` in Attendance component — errors now surface in browser console instead of silently returning `[]`

---

## 6. Live Status

| Module | Status |
|---|---|
| Workers (Active/GTV/Left tabs) | ✅ Working — 200+ workers at WWC |
| Attendance | ✅ Working — sessions load, absent marking works |
| New Registration | ✅ Working — DPDP consent on Step 6 |
| GTV Registration | ✅ Built |
| Session timeout | ✅ 30 min idle |
| DPDP consent columns | ✅ Live in DB |
| Payroll | ⏳ Phase 2 |
| Store operations | ⏳ Phase 2 |
| RA Bills / Billing | ⏳ Phase 2 |

---

## 7. Consultant Review — Trigger-Based Implementation Plan

| What | Trigger | Status |
|---|---|---|
| Daily backup | This week | ✅ Supabase daily snapshots verified |
| Session timeout | Before next new user | ✅ Done |
| DPDP consent | Before 500 workers | ✅ Done |
| Payroll module | When salary calc goes manual | ⏳ |
| Store operations | When paper register still used | ⏳ |
| RLS + service key → Edge Function | First external user login | ⏳ |
| Vite migration | File hits ~15,000 lines | ⏳ |
| Offline PWA | Internet fails at site twice | ⏳ |
| Biometric integration | Labour dispute over attendance | ⏳ |
| Multi-tenancy | Second legal entity / JV | ⏳ |

---

## 8. To Resume Next Session

Say: **"continue SiteOS"** — Claude will pick up from here.

Attach `siteos_v3_v3.html` only if code changes are needed.
List all tasks for the session in one message before starting.
Update this file after every session.
