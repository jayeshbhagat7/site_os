# SiteOS Business Rules & Standard Operating Procedures

> **Version:** 2.0  
> **Last Updated:** June 2026  
> **Source:** Extracted from `index.html` + owner briefing (Jayesh Bhagat, Umiya Associates)  
> **App:** SiteOS Construction ERP by Umiya Associates

---

## Table of Contents

1. [Role-Based Access Control](#1-role-based-access-control)
2. [Site Setup & Work Order](#2-site-setup--work-order)
3. [Worker Registration Workflow](#3-worker-registration-workflow)
4. [Worker Status Lifecycle](#4-worker-status-lifecycle)
5. [GTV (Gone To Village) Workflow](#5-gtv-gone-to-village-workflow)
6. [GTV Registration Module](#6-gtv-registration-module)
7. [Attendance & Haajri Rules](#7-attendance--haajri-rules)
8. [PPE Issuance Rules](#8-ppe-issuance-rules)
9. [Financial Rules — Kharchi, Payroll, Advances](#9-financial-rules--kharchi-payroll-advances)
10. [Expense & Petty Cash](#10-expense--petty-cash)
11. [Store Operations](#11-store-operations)
12. [Approval Workflow](#12-approval-workflow)
13. [Compliance & Statutory Requirements](#13-compliance--statutory-requirements)
14. [Session & Security Rules](#14-session--security-rules)
15. [Site Management Rules](#15-site-management-rules)
16. [Data Privacy (DPDP Compliance)](#16-data-privacy-dpdp-compliance)

---

## 1. Role-Based Access Control

### 1.1 System Roles

| Role | Description | Site Scope |
|------|-------------|------------|
| **Owner** | Full read access, all sites | All Sites (unrestricted) |
| **Admin** | Master tables, user creation | All Sites (unrestricted) |
| **Office** | Payroll + compliance, HO | All Sites (unrestricted) |
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

## 2. Site Setup & Work Order

### 2.1 New Site Onboarding

When a new project site is awarded:

1. **Site Code** is assigned (e.g., `WWC` for Wadhwa Wise City)
2. **Site ID** is auto-generated (SERIAL) in the `sites` table
3. **Address** and location details are entered
4. **Builder / Developer details** are recorded (`client_name` field)
5. **Job ID** is set — used as prefix for worker codes at that site (e.g., `WWC-00042`)

### 2.2 Work Order

The formal Work Order (WO) is signed between Umiya Associates and the client/developer. It contains:

| Section | Details |
|---------|---------|
| **Scope of Work** | Description of all work to be performed |
| **Mode of Measurement** | How quantities are measured (sqft, running metre, etc.) |
| **Payment Schedule** | Milestone-based or RA bill-based payment terms |
| **Terms & Conditions** | Agreed contractual terms |

- A site may be a **single building** or **multiple buildings/towers** within the same project
- Each building/tower is tracked in the `buildings` table linked to the site
- Work Orders are stored in the `work_orders` table (Phase 2 — Billing module)

### 2.3 Labour & Supervisor Deployment

- Workers and supervisors are **moved to the site** when it starts
- Existing workers in the system are searched first (to avoid duplication)
- If found, their record is updated with the new site assignment
- If new, a fresh registration is done via the Labour Entry wizard

---

## 3. Worker Registration Workflow

### 3.1 Why We Maintain Worker Data

The worker database serves these purposes:
- **Avoid duplication** — search existing records before registering a new worker
- **Document management** — Aadhaar, PAN, bank details, photos in one place
- **Compliance** — BOCW, MWF, PF, PT, ESIC records
- **History** — complete work history across all sites and projects
- **Daily wage rate** — maintained per worker, used for payroll calculation

### 3.2 Documents Required at Joining

| Document | Field | Mandatory |
|----------|-------|-----------|
| Aadhaar Card | `aadhaar_number` + `aadhaar_photo_url` | Yes |
| PAN Card | `pan_number` + `pan_photo_url` | Yes |
| Bank Account | `bank_account`, `bank_ifsc`, `bank_name` | Yes |
| Photograph | `worker_photo_url` | Yes |
| Labour Registration Form | Physical form filled at site | Yes |

### 3.3 Registration Wizard (6 Steps)

| Step | Name | Required Fields |
|------|------|-----------------|
| 1 | Site & Trade | Worker Code, Trade, Site, Date Joined |
| 2 | Personal Details | First Name or Worker Name |
| 3 | ID & Bank | None (optional at this step) |
| 4 | Documents | None (upload photos) |
| 5 | PPE Issue | None (toggle items) |
| 6 | Review & Submit | **DPDP Consent (mandatory)** |

**Component:** `LabourEntry`

### 3.4 Worker Code Auto-Generation

- **Format:** `{site_job_id}-{5-digit-sequence}` (e.g., `WWC-00042`)
- If site has a `job_id`, uses that as prefix with zero-padded sequence
- Scans existing workers with same prefix to determine next number
- Fallback (no site job_id): `UA-{5-digit-sequence}`

### 3.5 Returning Worker Rule

- **Before registering a new worker, always search existing records**
- If a worker previously worked with Umiya Associates, find their record and update it
- Update: new site assignment, new join date, updated rate, new documents if changed
- This preserves the full work history and avoids duplicate records

### 3.6 Entry Status Flow

```
draft --> pending_approval --> sic_approved --> active
  |              |
  |              +--> rejected --> (correct & resubmit) --> pending_approval
  |
  +--> (SIC/Admin saves) --> sic_approved (auto-approval)
```

### 3.7 Approval Rules

| Who Saves | Result |
|-----------|--------|
| **SIC or Admin** (new or draft) | Auto-approved: `entry_status = "sic_approved"`, `status = "Active"` |
| **Storekeeper** (new or draft) | Saved as `draft`, must manually submit for approval |
| **Storekeeper** submits | Moves to `pending_approval`, awaits SIC review |

**Key rule:** SIC/Admin registrations bypass the approval queue entirely.

### 3.8 SIC Approval with First Advance (Kharchi)

- When SIC approves a `pending_approval` worker:
  - Sets `entry_status = "sic_approved"`, `status = "Active"`
  - Records `sic_approved_by` and `sic_approved_at`
  - **First Kharchi:** ₹2,500 given at joining (amount may change — stored as `first_advance`)
  - Clears any previous `rejection_note`

### 3.9 Draft Saving

- Available from any wizard step once `worker_code` and `current_site_id` are filled
- Draft workers: `entry_status = "draft"`, `status = "Left"`, `is_active = true`
- Drafts persist across sessions (saved to DB immediately)

---

## 4. Worker Status Lifecycle

### 4.1 Worker Statuses

| Status | Meaning | When Set |
|--------|---------|----------|
| **Active** | Currently working on site | After SIC approval, or after rejoin from GTV |
| **GTV** | Gone To Village | When SIC/Admin marks GTV |
| **Left** | No longer employed | After 6 months GTV auto-expiry, manual mark, or draft state |
| **Transferred** | Moved to another site | After transfer approval |

### 4.2 Status Transitions

| From | To | Trigger | Who |
|------|-----|---------|-----|
| Active | GTV | Mark GTV action | SIC, Admin |
| Active | Transferred | Transfer approval | SIC (via approval) |
| Active | Left | Deactivation | SIC, Admin |
| GTV | Active | Rejoin action | SIC, Admin |
| GTV | Left | Manual mark left OR 6-month auto-expiry | SIC/Admin or System |
| Left | Active | Reactivation | SIC, Admin |

### 4.3 GTV Auto-Expiry (6-Month Rule)

- Workers on GTV status for > 6 months are automatically moved to "Left"
- Workers between 5 and 6 months get a warning notification on the dashboard
- Days remaining is calculated as: `GTV date + 6 months - today`

---

## 5. GTV (Gone To Village) Workflow

### 5.1 GTV Declaration Rules

- Worker **must declare at least 30 days in advance** if going to village
- Worker informs the **Storekeeper** first
- Storekeeper creates a GTV entry with the intended departure date
- Approval chain: Storekeeper entry → Supervisor → SIC → Owner

### 5.2 Payment Hold Rule

- If a worker leaves **without registering GTV**, the company may **hold payment for at least 1 month** to settle the account
- This is to ensure all advances, debits, and dues are reconciled before final payment

### 5.3 Direct GTV Marking (Urgent/Unregistered)

**WHO:** SIC, Admin only  
**WHEN:** Worker is Active and needs to go to village immediately  
**PROCESS:**

1. Select GTV date and optional promise date
2. System checks for unsubmitted attendance sessions between GTV date and today
3. If open sessions exist, user must resolve each one:
   - **Present** — leave as-is (company owes wages for that day)
   - **Absent** — correct attendance record to absent (haajri = 0)
4. All sessions must be resolved before GTV can be confirmed
5. Worker status changes: `Active` → `GTV`
6. Records `gtv_date` and optional `gtv_promise_date`
7. Logs event to `worker_history` table

### 5.4 GTV Actions (Rejoin / Mark Left)

- **Rejoin:** Sets status back to "Active", assigns new site, clears GTV dates, optionally updates rate
- **Mark Left:** Sets status to "Left"
- Both log to `worker_history`

---

## 6. GTV Registration Module

### 6.1 Overview

A formal advance-notice system for planned village visits. Requires approval chain before worker can officially go on GTV.

### 6.2 Registration Rules

| Rule | Detail |
|------|--------|
| Advance notice | Must register at least **1 month** in advance |
| Who registers | **Storekeeper only** |
| Eligible workers | Active workers at assigned site, not already registered for same month |
| Month selection | Next 1 to 4 months from current date |

### 6.3 Trade Caps (Company-Wide Per Month)

| Trade Group | Cap | Scope |
|-------------|-----|-------|
| Fitter | Max 10 workers | Company-wide per GTV month |
| Carpenter | Max 10 workers | Company-wide per GTV month |
| M/C + BRM + PLM (combined) | Max 10 workers | Company-wide per GTV month |
| All other trades | No cap | Unlimited |

### 6.4 Approval Chain

```
pending_supervisor --> pending_sic --> pending_owner --> approved
       |                    |                |
       +--> rejected        +--> rejected    +--> rejected
```

| Level | Approver | What They See |
|-------|----------|---------------|
| 1. Trade Supervisor | Carpenter/Fitter/Labour Supervisor | Only their trade's registrations |
| 2. SIC | SIC or Admin | All pending_sic registrations (site-scoped) |
| 3. Owner | Owner | All pending_owner registrations |

---

## 7. Attendance & Haajri Rules

### 7.1 What is Haajri

Haajri is the wage unit for a day's work. A worker may receive **3 to 5 haajri per day** depending on the work done:

| Haajri Value | Meaning |
|-------------|---------|
| 0 | Absent |
| 0.5 | Half day |
| 1.0 | Full day (default) |
| 1.5 | Overtime (1.5x) |
| 2.0 | Double shift |
| 3.0–5.0 | Piece-rate / task-based (supervisor discretion) |

**Daily wage calculation:** `Haajri × Per Day Rate`

### 7.2 Piece-Rate / Task-Based Haajri

- If a supervisor assigns a **part of work to a group of workers**, upon completion:
  - Supervisor calculates the haajri for each worker based on work done
  - Distributes and writes haajri in their individual cards
  - This haajri is then entered into the system
- Haajri values above 1.0 are valid and represent extra work/overtime

### 7.3 Monthly Salary Calculation

```
Monthly Salary = Sum of all daily Haajri × Per Day Rate
```

- Calculated at month end
- The total haajri for the month is summed from all attendance records
- Multiplied by the worker's `per_day_rate`
- Result is the gross salary before deductions

### 7.4 Session Model

| Field | Description |
|-------|-------------|
| `att_date` | Attendance date |
| `site_id` | Site for the session |
| `status` | draft → submitted → locked |
| `submitted_by` | Who submitted |
| `locked_by` | Who locked (SIC) |

- One session per site per date
- If no session exists for site+date, one is auto-created as "draft"

### 7.5 Building-Wise Allocation

- If a site has **multiple buildings/towers**, workers must be allocated building-wise when marking attendance
- This is done in the `attendance_building_assignments` table
- Allocation is required for cost tracking per building
- Workers can be split across buildings in a single day

### 7.6 Absent Worker Rule

- **An absent worker's haajri for that day CANNOT be entered on that day**
- Once marked absent and saved, the record is locked for the Storekeeper
- Only SIC can correct an absent mark (with mandatory correction note)

### 7.7 Session Status Flow

```
draft --> submitted --> locked
```

| Transition | Who | Action |
|-----------|-----|--------|
| draft → submitted | SK, SIC, or anyone with `can_add` Attendance | Submit button |
| submitted → locked | **SIC only** | Lock button |

### 7.8 Default Attendance

- **All workers are PRESENT by default** (haajri = 1.0)
- Marking absent is the exception action

### 7.9 Storekeeper Lock Rule

- **Storekeeper CANNOT change Absent → Present** on a saved record
- Once a worker is marked absent and saved, only SIC can correct it
- Error message: "Absent mark is saved. Request SIC to correct."

### 7.10 SIC Corrections

- SIC can flip Present ↔ Absent on any saved record
- Requires mandatory `correction_note`
- Records `corrected_by`, `corrected_at`
- Corrected records show "CORR" indicator

---

## 8. PPE Issuance Rules

### 8.1 PPE Items

| Item | Field | Tracked |
|------|-------|---------|
| Helmet | `helmet_issued` | Yes/No + issue date |
| Safety Belt | `belt_issued` | Yes/No + issue date |
| Gumboot | `gumboot_issued` | Yes/No + issue date |

### 8.2 Issuance Process

- PPE items are toggled during registration (Step 5)
- `issued_by` records who issued the PPE
- `worker_confirmed` tracks worker acknowledgment
- PPE data stored in `worker_ppe` table

### 8.3 Stock Deduction Rules

- **Only newly issued items are deducted** from store stock
- Comparison: `nowIssued && !wasIssued` (current toggle vs previous state)
- Re-editing a worker who already has PPE issued does NOT double-deduct

---

## 9. Financial Rules — Kharchi, Payroll, Advances

### 9.1 Kharchi (Advance Payment)

Kharchi is the advance cash given to workers for daily expenses:

| Rule | Detail |
|------|--------|
| **Joining Kharchi** | ₹2,500 given when worker joins (amount may change in future) |
| **Regular Kharchi** | Given at intervals: **10th, 20th, and 2nd of each month** |
| **Mode** | Bank transfer (to worker's registered bank account) |
| **Recording** | Recorded as `labour_advances` in the system |

### 9.2 Kharchi Deduction from Salary

- All kharchi given during the month is deducted from the monthly salary
- `Net Payable = Gross Wages - Total Kharchi/Advances + Carry Forward`
- If advances exceed earnings, the excess is carried forward to next month

### 9.3 Payroll Calculation

- **Gross Wages:** `days_present × per_day_rate` (days_present = sum of haajri for date range)
- **Net Payable:** `gross_wages - advances_deducted + carry_forward_in`
- **Carry Forward:** `max(0, advances - gross - carry_forward_in)`
- Carry forward from last paid run is brought into next calculation

### 9.4 Salary Processing

1. Payroll is calculated in SiteOS (Payroll module)
2. The **final list of all worker salaries is forwarded to Head Office**
3. HO applies statutory compliance calculations (BOCW, MWF, PF, PT, ESIC)
4. Final salary is processed via **bank transfer** to each worker's account

### 9.5 Payroll Run Status

```
draft --> paid (irreversible)
```

- "Mark as Paid" requires confirmation and cannot be undone

---

## 10. Expense & Petty Cash

### 10.1 Petty Cash Flow

```
Owner → gives cash to SIC → SIC gives to Storekeeper → Storekeeper spends
```

- **Owner** provides petty cash to the SIC for site operations
- **SIC** distributes to Storekeeper as needed for day-to-day expenses
- **Storekeeper** records each expense against the petty cash balance
- Each person has a **Cash Wallet** in the system tracking their balance

### 10.2 Expense Categories

| Category | Code |
|----------|------|
| Hardware | H/W |
| Stationary | Stationary |
| Labour Salary | Labour Salary |
| Fuel | Fuel |
| Repairing | Repairing |
| Transportation | Transportation |
| Travelling | Travelling |
| Medical | Medical |
| Other | Other |

### 10.3 Current Process (Being Replaced)

- Currently each user records expenses in **Google Sheets**
- The final account list is forwarded to **Head Office every month**
- SiteOS Expense module replaces this Google Sheets process

### 10.4 Expense Recording Rules

- Each expense is recorded with: date, category, amount, description, paid from wallet
- Wallet balance is debited when expense is recorded
- Reference number (bill/invoice/voucher) can be attached
- Expenses above a threshold may require SIC approval

### 10.5 Wallet Top-Up

- Owner sends cash to SIC wallet → recorded as `wallet_topup`
- SIC sends cash to Storekeeper wallet → recorded as `wallet_transaction`
- All movements are traceable in the transaction ledger

### 10.6 Monthly Reporting

- Monthly expense summary is generated per site
- Forwarded to HO for accounts reconciliation
- Replaces the current Google Sheets monthly submission

---

## 11. Store Operations

### 11.1 Inward Register (GRN)

- All material received at site is entered in the **Inward Register**
- Each entry gets a **Register Number** (auto: `GRN/YYYY/NNN`)
- The respective **Material Ledger** is updated with the register number and material details

### 11.2 Material Types

| Type | Description |
|------|-------------|
| **Purchased** | Material bought via PO from vendor |
| **FOC (Free of Cost)** | Material provided by client at no charge |
| **Returnable** | Client material that must be returned (e.g., formwork) |
| **Non-Returnable** | Client material consumed at site |

### 11.3 FOC Material Rules

- FOC material from client is tracked separately
- **Returnable FOC:** Reconciliation record must be prepared and submitted when asked
- **Non-Returnable FOC:** Consumed at site, recorded in ledger for compliance
- Reconciliation reports are generated from the stock ledger

### 11.4 Store Operations Flow

```
Material Requisition → Purchase Order → GRN (Inward) → Stock Ledger → Material Issue
```

### 11.5 Material Issue

- Material issued from store to site/wing is recorded in `material_issues`
- Issue number auto-generated: `ISS/YYYY/NNN`
- Stock ledger is updated on issue

---

## 12. Approval Workflow

### 12.1 Approval Types

| Type | Description | Approver Role |
|------|-------------|---------------|
| `debit_rate` | Material debit to worker salary | SIC |
| `worker_transfer` | Transfer worker between sites | SIC |
| `material_request` | Request materials | SIC |
| `salary_submission` | Salary submission for payment | Office |
| `gtv_registration` | GTV advance notice | Supervisor → SIC → Owner |

### 12.2 Who Can Approve

| User Role | Can Approve |
|-----------|-------------|
| Admin | All approval types |
| SIC | Approvals where `approver_role = "SIC"` (site-scoped) |
| Office | Approvals where `approver_role = "Office"` |
| Owner | GTV final approval |

### 12.3 Approval Side Effects

**Worker Transfer (on approve):**
- Worker's `current_site_id` updated to destination site
- Worker's `current_store_id` cleared
- Worker status set to "Active"

**Debit Rate (on approve):**
- `worker_debit_log` updated with `debit_rate` and calculated `debit_amount`
- Status set to "approved"

---

## 13. Compliance & Statutory Requirements

### 13.1 Applicable Regulations

All workers in the construction industry are subject to:

| Regulation | Full Name | Applicability |
|-----------|-----------|---------------|
| **BOCW** | Building & Other Construction Workers Act | All construction workers |
| **MWF** | Maharashtra Workers' Welfare Fund | Maharashtra sites |
| **PF** | Provident Fund (EPF) | Workers earning above threshold |
| **PT** | Professional Tax | Maharashtra |
| **ESIC** | Employees' State Insurance | Workers earning ≤ ₹21,000/month |

### 13.2 Compliance Data Maintained

- Worker's `esic_eligible` flag (boolean)
- Worker's `esic_ip_number` (ESIC IP number)
- Worker's `pf_uan_number` (PF UAN)
- Worker's `pan_number` (for TDS if applicable)

### 13.3 Salary Submission to HO

1. SiteOS generates the payroll run (gross wages per worker)
2. List is forwarded to Head Office
3. HO applies BOCW, MWF, PF, PT, ESIC deductions as applicable
4. Final net salary is processed via bank transfer
5. Compliance returns are filed by HO

---

## 14. Session & Security Rules

### 14.1 Idle Session Timeout

- **Duration:** 30 minutes of inactivity
- **Events that reset timer:** mousemove, mousedown, keydown, touchstart, scroll, click
- **On expiry:** Auto signs out, shows alert, returns to login
- Timer starts immediately on login

### 14.2 Login Requirements

- Email + password authentication via Supabase Auth
- User must have a profile in `app_users` table linked by `auth_id`
- User must have `is_active = true`
- Login lockout: 5 failed attempts → 15-minute lock

### 14.3 Data Caching

- Query results cached for 2 minutes to reduce Supabase egress
- Cache cleared on logout

---

## 15. Site Management Rules

### 15.1 Site Deactivation Guards

- **WHO:** Only Owner/Admin can deactivate a site
- **GUARD:** Cannot deactivate if active workers remain assigned
- Error: "Cannot deactivate: X active worker(s) still assigned."
- All active workers must be moved (transfer, GTV, or left) before site can be deactivated

### 15.2 Worker Transfer

- Transfer request creates an approval entry (type: "worker_transfer", approver: SIC)
- Cannot transfer to same site
- On approval: worker's site changes, store cleared, status remains Active

---

## 16. Data Privacy (DPDP Compliance)

### 16.1 Consent Requirement

- **MANDATORY** on Step 6 (Review & Submit) of registration wizard
- The `consent_given` checkbox MUST be checked before final save is allowed

### 16.2 Consent Text

> "I confirm that the worker has been informed about and has verbally consented to the collection and storage of their personal data (name, Aadhaar, PAN, bank details, photograph, attendance records) for employment and statutory compliance purposes by Umiya Associates, as required under the Digital Personal Data Protection Act 2023."

### 16.3 Consent Recording

- `consent_given`: boolean flag
- `consent_date`: date when consent was recorded (auto-set to today)

---

## Appendix A: Key Component Reference

| Component | Purpose |
|-----------|---------|
| `LabourEntry` | 6-step registration wizard, draft/submit/approve |
| `WorkerMaster` | Worker list, GTV marking, transfer, debit, reactivation |
| `Attendance` | Session management, absent marking, haajri, corrections |
| `GTVRegistration` | Formal advance GTV registration with trade caps |
| `Approvals` | Central approval queue for transfers, debits, materials |
| `PolicyMaster` | Role permission matrix management |
| `PayrollModule` | Wage calculation, advances, payroll runs |
| `ExpenseModule` | Petty cash recording, wallet top-ups, monthly summary |
| `SiteMaster` | Site CRUD with deactivation guards |
| `App` | Auth context, idle timeout, navigation routing |

## Appendix B: Phase 2 Build Order

| Priority | Module | Trigger | Status |
|----------|--------|---------|--------|
| 1 | Payroll | Salary calc still manual | ✅ Built |
| 2 | Expense & Petty Cash | Google Sheets still in use | 🔨 Building |
| 3 | Inward Register (GRN) | Paper challan register in use | ⏳ |
| 4 | Material Issue | Issues not tracked digitally | ⏳ |
| 5 | Stock Ledger | No real-time stock visibility | ⏳ |
| 6 | Procurement / PO | POs raised manually | ⏳ |
| 7 | Work Orders | WOs written on paper | ⏳ |
| 8 | RA Bills | RA bill calc still manual | ⏳ |
| 9 | Reports | Management asks for summary | ⏳ |
