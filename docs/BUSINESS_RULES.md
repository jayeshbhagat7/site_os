# SiteOS Business Rules & Standard Operating Procedures

> **Version:** 1.0  
> **Last Updated:** 2025-01-XX  
> **Source:** Extracted from `index.html` application code  
> **App:** SiteOS Construction ERP by Umiya Associates

---

## Table of Contents

1. [Role-Based Access Control](#1-role-based-access-control)
2. [Worker Registration Workflow](#2-worker-registration-workflow)
3. [Worker Status Lifecycle](#3-worker-status-lifecycle)
4. [GTV (Gone To Village) Workflow](#4-gtv-gone-to-village-workflow)
5. [GTV Registration Module](#5-gtv-registration-module)
6. [Attendance Rules](#6-attendance-rules)
7. [PPE Issuance Rules](#7-ppe-issuance-rules)
8. [Financial Rules (Payroll, Advances, Debit)](#8-financial-rules)
9. [Approval Workflow](#9-approval-workflow)
10. [Session & Security Rules](#10-session--security-rules)
11. [Site Management Rules](#11-site-management-rules)
12. [Data Privacy (DPDP Compliance)](#12-data-privacy-dpdp-compliance)

---

## 1. Role-Based Access Control

### 1.1 System Roles

| Role | Description | Site Scope |
|------|-------------|------------|
| **Owner** | Full read access, all sites | All Sites (unrestricted) |
| **Admin** | Master tables, user creation | All Sites (unrestricted) |
| **Office** | Payroll + compliance | All Sites (unrestricted) |
| **SIC** | Full access, assigned site(s) | Assigned Sites only |
| **Supervisor** | Attendance + DPR, own site | Assigned Site only |
| **Storekeeper** | Store inward/issue, own site | Assigned Site only |

### 1.2 Site Scope Rules

- **Unrestricted roles** (Owner, Admin, Office): See all sites without restriction (`isUnrestricted = true`)
- **Restricted roles** (SIC, Supervisor, Storekeeper): Only see data for their assigned sites (`assignedSiteIds`)
- If a user has exactly one assigned site, it is auto-selected on login
- Users may have multiple assigned sites (via `user_sites` table, fallback to `assigned_site_id`)

### 1.3 Permission System

**Policy Master** controls module-level permissions per role:

| Permission | Description |
|-----------|-------------|
| `can_view` | View module data |
| `can_add` | Create new records |
| `can_edit` | Modify existing records |
| `can_delete` | Remove records |
| `can_approve` | Approve requests |
| `can_export` | Export data |
| `can_print` | Print forms/reports |

**Modules:** Store, Labour, Payroll, Expense, Attendance, DPR, Procurement, Compliance, Reports, Masters, Billing

### 1.4 User Policy Overrides

- Per-user overrides replace role defaults for specific modules (stored in `user_policy_overrides` table)
- Merge logic: Remove role permissions for overridden modules, then add user-specific permissions

### 1.5 Navigation Visibility Rules

| Navigation Item | Visible To |
|----------------|------------|
| Dashboard, Approvals | All authenticated users |
| Users & Roles, Policies | Owner, Admin only (`adminOnly`) |
| Sites, Stores, Buildings | Owner, Admin only (`ownerOnly`) |
| GTV Registration | SIC, Admin, Owner only (`sic`) |
| Billing modules | Owner, Admin, SIC only |
| All other modules | Based on `can_view` policy permission |

### 1.6 Custom Roles

- Admin can create custom roles beyond the 6 system roles
- System roles (Owner, SIC, Supervisor, Storekeeper, Office, Admin) cannot be deleted
- Custom roles can be given "View Only" or "Full Access" presets

---

## 2. Worker Registration Workflow

### 2.1 Registration Wizard (6 Steps)

| Step | Name | Required Fields |
|------|------|-----------------|
| 1 | Site & Trade | Worker Code, Trade, Site, Date Joined |
| 2 | Personal Details | First Name or Worker Name |
| 3 | ID & Bank | None (optional) |
| 4 | Documents | None (upload photos) |
| 5 | PPE Issue | None (toggle items) |
| 6 | Review & Submit | **DPDP Consent (mandatory)** |

**Component:** `LabourEntry`

### 2.2 Worker Code Auto-Generation

- **Format:** `{site_job_id}-{5-digit-sequence}` (e.g., `WWC-00042`)
- If site has a `job_id`, uses that as prefix with zero-padded sequence
- Scans existing workers with same prefix to determine next number
- Fallback (no site job_id): `UA-{5-digit-sequence}`

### 2.3 Entry Status Flow

```
draft --> pending_approval --> sic_approved --> active
  |              |
  |              +--> rejected --> (correct & resubmit) --> pending_approval
  |
  +--> (SIC/Admin saves) --> sic_approved (auto-approval)
```

### 2.4 Approval Rules

| Who Saves | Result |
|-----------|--------|
| **SIC or Admin** (new or draft) | Auto-approved: `entry_status = "sic_approved"`, `status = "Active"` |
| **Storekeeper** (new or draft) | Saved as `draft`, must manually submit for approval |
| **Storekeeper** submits | Moves to `pending_approval`, awaits SIC review |

**Key rule:** SIC/Admin registrations bypass the approval queue entirely.

### 2.5 SIC Approval with First Advance

- When SIC approves a `pending_approval` worker:
  - Sets `entry_status = "sic_approved"`, `status = "Active"`
  - Records `sic_approved_by` and `sic_approved_at`
  - Optionally sets `first_advance` amount
  - Clears any previous `rejection_note`

### 2.6 Rejection & Resubmission

- **WHO:** Only SIC/Admin can reject
- **WHEN:** Worker has `entry_status = "pending_approval"`
- **WHAT:** Sets `entry_status = "rejected"` with mandatory `rejection_note`
- **RESUBMIT:** Storekeeper or SIC can open the rejected worker, correct issues, then resubmit

### 2.7 Draft Saving

- Available from any wizard step once `worker_code` and `current_site_id` are filled
- Draft workers: `entry_status = "draft"`, `status = "Left"`, `is_active = true`
- Drafts persist across sessions (saved to DB immediately)
- New draft inserts a worker row; subsequent saves update the same row

### 2.8 Job Number Auto-Fill

- When site is selected in the form, `job_no` auto-fills from the site's `job_id`
- Does not override if user has manually changed it

---

## 3. Worker Status Lifecycle

### 3.1 Worker Statuses

| Status | Meaning | When Set |
|--------|---------|----------|
| **Active** | Currently working on site | After SIC approval, or after rejoin from GTV |
| **GTV** | Gone To Village | When SIC/Admin marks GTV |
| **Left** | No longer employed | After 6 months GTV auto-expiry, manual mark, or draft state |
| **Transferred** | Moved to another site | After transfer approval |

### 3.2 Status Transitions

| From | To | Trigger | Who |
|------|-----|---------|-----|
| Active | GTV | Mark GTV action | SIC, Admin |
| Active | Transferred | Transfer approval | SIC (via approval) |
| Active | Left | Deactivation | SIC, Admin |
| GTV | Active | Rejoin action | SIC, Admin |
| GTV | Left | Manual mark left OR 6-month auto-expiry | SIC/Admin or System |
| Left | Active | Reactivation | SIC, Admin |

### 3.3 GTV Auto-Expiry (6-Month Rule)

- **Checked on:** Dashboard load by SIC/Admin/Owner
- Workers on GTV status for > 6 months are automatically moved to "Left"
- Workers between 5 and 6 months get a warning notification on the dashboard
- Days remaining is calculated as: `GTV date + 6 months - today`

### 3.4 Worker Reactivation

- Only available for workers with status "Left"
- Requires: site assignment, valid per_day_rate
- Optionally set: store, building, date joined

---

## 4. GTV (Gone To Village) Workflow

### 4.1 Direct GTV Marking (Urgent/Unregistered)

**Component:** `WorkerMaster` (openMarkGTV, submitMarkGTV)

**WHO:** SIC, Admin only  
**WHEN:** Worker is Active and needs to go to village immediately  
**PROCESS:**

1. Select GTV date and optional promise date
2. System checks for unsubmitted attendance sessions between GTV date and today
3. If open sessions exist, user must resolve each one:
   - **Present** - leave as-is (company owes wages for that day)
   - **Absent** - correct attendance record to absent (haajri = 0, daily_wage = 0)
4. All sessions must be resolved before GTV can be confirmed
5. Worker status changes: `Active` -> `GTV`
6. Records `gtv_date` and optional `gtv_promise_date`
7. Logs event to `worker_history` table

### 4.2 GTV Actions (Rejoin / Mark Left)

- **Rejoin:** Sets status back to "Active", assigns new site, clears GTV dates, optionally updates rate
- **Mark Left:** Sets status to "Left"
- Both log to `worker_history`

---

## 5. GTV Registration Module

### 5.1 Overview

**Component:** `GTVRegistration`

A formal advance-notice system for planned village visits. Requires approval chain before worker can officially go on GTV.

### 5.2 Registration Rules

| Rule | Detail |
|------|--------|
| Advance notice | Must register at least **1 month** in advance |
| Who registers | **Storekeeper only** |
| Eligible workers | Active workers at assigned site, not already registered for same month |
| Month selection | Next 1 to 4 months from current date |

### 5.3 Trade Caps (Company-Wide Per Month)

| Trade Group | Cap | Scope |
|-------------|-----|-------|
| Fitter | Max 10 workers | Company-wide per GTV month |
| Carpenter | Max 10 workers | Company-wide per GTV month |
| M/C + BRM + PLM (combined) | Max 10 workers | Company-wide per GTV month |
| All other trades | No cap | Unlimited |

Cap is checked against approved + pending registrations for that month across all sites.

### 5.4 Approval Chain

```
pending_supervisor --> pending_sic --> pending_owner --> approved
       |                    |                |
       +--> rejected        +--> rejected    +--> rejected
```

| Level | Approver | What They See |
|-------|----------|---------------|
| 1. Trade Supervisor | Carpenter Supervisor, Fitter Supervisor, or Labour Supervisor | Only their trade's registrations |
| 2. SIC | SIC or Admin | All pending_sic registrations (site-scoped) |
| 3. Owner | Owner | All pending_owner registrations |

### 5.5 Supervisor Trade Mapping

| Worker Trade | Supervisor Role |
|-------------|-----------------|
| Carpenter | Carpenter Supervisor |
| Fitter | Fitter Supervisor |
| M/C, BRM, PLM | Labour Supervisor |
| All others | Skip supervisor, go directly to SIC |

### 5.6 Rejection

- Rejection reason is mandatory
- Optional `payment_hold` flag can be set on rejection
- Rejected registrations can be re-registered

---

## 6. Attendance Rules

### 6.1 Session Model

**Component:** `Attendance`

| Field | Description |
|-------|-------------|
| `att_date` | Attendance date |
| `site_id` | Site for the session |
| `status` | draft -> submitted -> locked |
| `submitted_by` | Who submitted |
| `locked_by` | Who locked (SIC) |

- One session per site per date
- If no session exists for site+date, one is auto-created as "draft"

### 6.2 Session Status Flow

```
draft --> submitted --> locked
```

| Transition | Who | Action |
|-----------|-----|--------|
| draft -> submitted | SK, SIC, or anyone with `can_add` Attendance | Submit button |
| submitted -> locked | **SIC only** | Lock button |

### 6.3 Default Attendance

- **All workers are PRESENT by default** (haajri = 1.0)
- Marking absent is the exception action
- Present workers get default haajri of 1.0 (full day)

### 6.4 Haajri (Wage Units)

| Value | Meaning |
|-------|---------|
| 0 | Absent |
| 0.5 | Half day |
| 1.0 | Full day (default) |
| 1.5 | Overtime (1.5x) |
| 2.0 | Double shift |

**Daily wage calculation:** `Haajri x Per Day Rate`

### 6.5 Storekeeper Lock Rule (SK Lock)

- **Storekeeper CANNOT change Absent -> Present** on a saved (non-new) record
- Once a worker is marked absent and saved, only SIC can correct it
- Error message: "Absent mark is saved. Request SIC to correct."
- Visual indicator: "LOCKED" label on the record

### 6.6 Session Lock Rule

- If session status = "locked" and user is NOT SIC: all edits blocked
- Error: "Session locked -- SIC correction required"

### 6.7 Haajri Entry Permissions

| Role | Can Enter Haajri? | Constraints |
|------|-------------------|-------------|
| Storekeeper | Yes | Cannot edit absent worker haajri |
| Supervisor | Yes | Once saved, only SIC can re-edit |
| SIC / Admin | Yes | Full edit always |

### 6.8 Trade Supervisor Filtering

- Trade-specific supervisors (e.g., "Carpenter Supervisor") only see workers of their trade
- The trade is extracted from the role name: "Carpenter Supervisor" -> filters to "Carpenter"
- Generic "Supervisor" role sees all workers

### 6.9 SIC Corrections

**Single Correction:**
- SIC can flip Present <-> Absent on any saved record
- Requires mandatory `correction_note`
- Records `corrected_by`, `corrected_at`
- Corrected records show "CORR" indicator

**Bulk Correction:**
- SIC can select a date + site and load all absent workers
- Select multiple workers and correct to Present with a note
- Refreshes current session if same date/site

### 6.10 Bulk Mark Absent

- Available to users with `can_add` Attendance permission
- Select multiple present workers via checkboxes
- Cannot bulk-select workers that are already absent or SK-locked
- Confirm marks all selected as absent (haajri = 0)

---

## 7. PPE Issuance Rules

### 7.1 PPE Items

| Item | Field | Tracked |
|------|-------|---------|
| Helmet | `helmet_issued` | Yes/No + issue date |
| Safety Belt | `belt_issued` | Yes/No + issue date |
| Gumboot | `gumboot_issued` | Yes/No + issue date |

### 7.2 Issuance Process (Registration Wizard Step 5)

- PPE items are toggled during registration
- `issued_by` records who issued the PPE
- `worker_confirmed` tracks worker acknowledgment
- PPE data stored in `worker_ppe` table (source of truth)

### 7.3 Stock Deduction Rules

- **Only newly issued items are deducted** from store stock
- Comparison: `nowIssued && !wasIssued` (current toggle vs previous state in `worker_ppe`)
- Re-editing a worker who already has PPE issued does NOT double-deduct
- Deduction looks up material by name (ilike match) in `materials` table

### 7.4 PPE Log

- Each new issuance creates a record in `worker_ppe_log`
- Log fields: `worker_id`, `site_id`, `ppe_item`, `action` ("issued"), `action_date`, `notes`, `done_by`
- Action date defaults to worker's `date_joined`

---

## 8. Financial Rules

### 8.1 First Advance

- Given at time of SIC approval (optional)
- Stored in `first_advance` field on worker record
- Amount set by SIC during the approval modal
- Leaving as 0 means no advance given

### 8.2 Labour Advances

- Recorded per worker per site
- Fields: `worker_id`, `site_id`, `amount`, `payment_date`, `mode_type` (cash/bank), `wallet_id`
- Mode types: cash, bank
- If mode is cash, optionally linked to a `cash_wallet`

### 8.3 Cash Wallets

- Named cash holders (petty cash wallets) tracked in `cash_wallets` table
- Each wallet has `person_name` and `current_balance`
- Used for recording cash advance payments

### 8.4 Debit Voucher (Debit Rate)

- **WHO:** Any user with edit permission in Workers module
- **WHAT:** Records material issued to a worker to be deducted from salary
- **PROCESS:**
  1. Select material, quantity, optional salary_month, reason
  2. Creates record in `worker_debit_log` with status "pending_approval"
  3. Creates corresponding entry in `approvals` table (type: "debit_rate", approver: SIC)
  4. SIC reviews and sets the debit rate (price per unit)
  5. On approval: `debit_amount = approved_rate x quantity`

### 8.5 Payroll Calculation

- **Gross Wages:** `days_present x per_day_rate` (days_present = sum of haajri for date range)
- **Net Payable:** `gross_wages - advances_deducted + carry_forward_in`
- **Carry Forward:** `max(0, advances - gross - carry_forward_in)` (when advances exceed earnings)
- Carry forward from last paid run is brought into next calculation

### 8.6 Payroll Run Status

```
draft --> paid (irreversible)
```

- "Mark as Paid" requires confirmation and cannot be undone
- Updates both `payroll_runs` and all `payroll_entries` for that run

---

## 9. Approval Workflow

### 9.1 Approval Types

| Type | Description | Approver Role |
|------|-------------|---------------|
| `debit_rate` | Material debit to worker salary | SIC |
| `worker_transfer` | Transfer worker between sites | SIC |
| `material_request` | Request materials | SIC |
| `salary_submission` | Salary submission for payment | Office |

### 9.2 Who Can Approve

| User Role | Can Approve |
|-----------|-------------|
| Admin | All approval types |
| SIC | Approvals where `approver_role = "SIC"` (site-scoped) |
| Office | Approvals where `approver_role = "Office"` |

### 9.3 Approval Side Effects

**Worker Transfer (on approve):**
- Worker's `current_site_id` updated to destination site
- Worker's `current_store_id` cleared
- Worker status set to "Active"

**Debit Rate (on approve):**
- `worker_debit_log` updated with `debit_rate` and calculated `debit_amount`
- Status set to "approved"

### 9.4 Rejection

- Mandatory rejection note/reason
- Status set to "rejected" with `rejection_note` stored

---

## 10. Session & Security Rules

### 10.1 Idle Session Timeout

- **Duration:** 30 minutes of inactivity
- **Events that reset timer:** mousemove, mousedown, keydown, touchstart, scroll, click
- **On expiry:** Auto signs out via `sb.auth.signOut()`, shows alert, returns to login
- Timer starts immediately on login

### 10.2 Login Requirements

- Email + password authentication via Supabase Auth
- User must have a profile in `app_users` table linked by `auth_id`
- User must have `is_active = true` (deactivated accounts are blocked)
- Error: "User profile not found" if `app_users` record missing
- Error: "Account deactivated" if `is_active = false`

### 10.3 Data Caching

- Query results cached for 2 minutes (`_cache` with 120000ms TTL)
- Cache cleared on logout
- Reduces Supabase egress for repeated navigation

### 10.4 Photo Upload Security

- Worker document photos uploaded via `sbAdmin` (service role client) to bypass RLS on storage bucket
- Fallback: Base64 encoding for photos under 300KB if storage fails
- Bucket: "worker-docs"

---

## 11. Site Management Rules

### 11.1 Site Deactivation Guards

- **WHO:** Only Owner/Admin can deactivate a site
- **GUARD:** Cannot deactivate if active workers remain assigned
- Error: "Cannot deactivate: X active worker(s) still assigned. Transfer or mark them as GTV first."
- All active workers must be moved (transfer, GTV, or left) before site can be deactivated

### 11.2 Worker Transfer

- Transfer request creates an approval entry (type: "worker_transfer", approver: SIC)
- Also creates record in `worker_transfers` table with the approval_id
- Cannot transfer to same site
- Transfer type: "permanent" (default)
- On approval: worker's site changes, store cleared, status remains Active

---

## 12. Data Privacy (DPDP Compliance)

### 12.1 Consent Requirement

- **MANDATORY** on Step 6 (Review & Submit) of registration wizard
- The `consent_given` checkbox MUST be checked before final save is allowed
- `stepValid()` for step 6 returns `!!form.consent_given`

### 12.2 Consent Text

> "I confirm that the worker has been informed about and has verbally consented to the collection and storage of their personal data (name, Aadhaar, PAN, bank details, photograph, attendance records) for employment and statutory compliance purposes by Umiya Associates, as required under the Digital Personal Data Protection Act 2023."

### 12.3 Consent Recording

- `consent_given`: boolean flag
- `consent_date`: date when consent was recorded (auto-set to today)
- Recorded by: current user's name displayed in UI

---

## Appendix: Print/ID Card Eligibility

### Print Form (Official Registration Form)

- **Available when:** `entry_status === "sic_approved"` OR `entry_status === "active"`
- Shows full worker details with PPE status loaded from `worker_ppe` table
- Error if worker not yet approved: "Official form is only available after SIC approval"

### ID Card

- **Available when:** `entry_status === "sic_approved"` OR `entry_status === "active"`
- Only shows action button for approved workers

---

## Appendix: Key Component Reference

| Component | Purpose |
|-----------|---------|
| `LabourEntry` | 6-step registration wizard, draft/submit/approve |
| `WorkerMaster` | Worker list, GTV marking, transfer, debit, reactivation |
| `Attendance` | Session management, absent marking, haajri, corrections |
| `GTVRegistration` | Formal advance GTV registration with trade caps |
| `Approvals` | Central approval queue for transfers, debits, materials |
| `PolicyMaster` | Role permission matrix management |
| `PayrollModule` | Wage calculation, advances, payroll runs |
| `SiteMaster` | Site CRUD with deactivation guards |
| `App` | Auth context, idle timeout, navigation routing |
