-- ================================================================
-- SiteOS — Expense & Petty Cash Schema
-- Run in Supabase SQL Editor
-- Safe to re-run (uses IF NOT EXISTS)
-- ================================================================

-- ── EXPENSE CATEGORIES ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.expense_categories (
  category_id   SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  display_name  TEXT NOT NULL,
  is_active     BOOLEAN DEFAULT true,
  tenant_id     UUID,  -- nullable: categories are global across tenants
  created_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.expense_categories DISABLE ROW LEVEL SECURITY;

-- Drop NOT NULL on tenant_id if it was previously created with constraint
ALTER TABLE public.expense_categories ALTER COLUMN tenant_id DROP NOT NULL;

-- Seed default categories (matches uauat site_expense_category)
INSERT INTO public.expense_categories (name, display_name) VALUES
  ('hardware',       'H/W'),
  ('stationary',     'Stationary'),
  ('labour_salary',  'Labour Salary'),
  ('fuel',           'Fuel'),
  ('repairing',      'Repairing'),
  ('transportation', 'Transportation'),
  ('travelling',     'Travelling'),
  ('medical',        'Medical'),
  ('kharchi',        'Kharchi / Advance'),
  ('other',          'Other')
ON CONFLICT DO NOTHING;

-- ── SITE EXPENSES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.site_expenses (
  expense_id        SERIAL PRIMARY KEY,
  site_id           INT NOT NULL REFERENCES public.sites(site_id),
  expense_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  category_id       INT REFERENCES public.expense_categories(category_id),
  description       TEXT NOT NULL,
  amount            NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  paid_from_wallet  INT REFERENCES public.cash_wallets(wallet_id),
  reference_no      TEXT DEFAULT '',
  worker_id         INT REFERENCES public.workers(id),
  requires_approval BOOLEAN DEFAULT false,
  approved_by       UUID REFERENCES public.app_users(user_id),
  approved_at       TIMESTAMPTZ,
  status            TEXT DEFAULT 'recorded'
                    CHECK (status IN ('recorded','approved','rejected')),
  created_by        UUID NOT NULL REFERENCES public.app_users(user_id),
  created_at        TIMESTAMPTZ DEFAULT now(),
  tenant_id         UUID REFERENCES public.tenants(tenant_id)
);
ALTER TABLE public.site_expenses DISABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_site_expenses_site
  ON public.site_expenses(site_id, expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_site_expenses_wallet
  ON public.site_expenses(paid_from_wallet);
CREATE INDEX IF NOT EXISTS idx_site_expenses_date
  ON public.site_expenses(expense_date DESC);

-- ── WALLET TOP-UPS ───────────────────────────────────────────────
-- Records cash received into a wallet (from Owner, bank, external)
CREATE TABLE IF NOT EXISTS public.wallet_topups (
  topup_id        SERIAL PRIMARY KEY,
  to_wallet_id    INT NOT NULL REFERENCES public.cash_wallets(wallet_id),
  from_wallet_id  INT REFERENCES public.cash_wallets(wallet_id),
  amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  topup_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  description     TEXT DEFAULT '',
  mode            TEXT DEFAULT 'cash'
                  CHECK (mode IN ('cash','bank','upi','cheque')),
  cheque_no       TEXT,
  created_by      UUID NOT NULL REFERENCES public.app_users(user_id),
  created_at      TIMESTAMPTZ DEFAULT now(),
  tenant_id       UUID REFERENCES public.tenants(tenant_id)
);
ALTER TABLE public.wallet_topups DISABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_wallet_topups_date
  ON public.wallet_topups(topup_date DESC);

-- ── LOGIN ATTEMPTS (for lockout) ─────────────────────────────────
-- Already created in database/login_attempts_schema.sql
-- Included here for completeness
CREATE TABLE IF NOT EXISTS public.login_attempts (
  id            SERIAL PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  failed_count  INT DEFAULT 0,
  locked_until  TIMESTAMPTZ,
  last_attempt  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.login_attempts DISABLE ROW LEVEL SECURITY;

-- ================================================================
-- VERIFY
-- ================================================================
SELECT
  (SELECT COUNT(*) FROM public.expense_categories) AS expense_categories,
  (SELECT COUNT(*) FROM public.site_expenses)       AS site_expenses,
  (SELECT COUNT(*) FROM public.wallet_topups)       AS wallet_topups;
