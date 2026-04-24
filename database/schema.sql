-- ============================================
-- SITEOS DATABASE SCHEMA
-- For Supabase PostgreSQL
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- SITES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS sites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  location TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX idx_sites_user_id ON sites(user_id);

-- ============================================
-- WORKERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS workers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
  
  -- Basic Info
  code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  trade VARCHAR(100),
  rate DECIMAL(10,2) DEFAULT 0,
  
  -- Status & Dates
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'gtv', 'left')),
  join_date DATE,
  gtv_date DATE,
  gtv_promise_date DATE,
  gtv_reason TEXT,
  left_date DATE,
  
  -- Attendance tracking
  attendance_sessions INTEGER DEFAULT 0,
  
  -- Contact & Documents
  phone VARCHAR(20),
  aadhaar VARCHAR(20),
  photo_url TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_workers_user_id ON workers(user_id);
CREATE INDEX idx_workers_site_id ON workers(site_id);
CREATE INDEX idx_workers_status ON workers(status);
CREATE INDEX idx_workers_code ON workers(code);

-- ============================================
-- ATTENDANCE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  worker_id UUID NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
  
  -- Attendance Details
  date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'present' CHECK (status IN ('present', 'absent', 'half_day', 'overtime')),
  hours DECIMAL(4,2) DEFAULT 8.0,
  
  -- Payment
  rate DECIMAL(10,2) DEFAULT 0,
  amount DECIMAL(10,2) DEFAULT 0,
  
  -- Notes
  notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate entries
  UNIQUE(worker_id, date)
);

-- Indexes
CREATE INDEX idx_attendance_user_id ON attendance(user_id);
CREATE INDEX idx_attendance_worker_id ON attendance(worker_id);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_attendance_site_id ON attendance(site_id);

-- ============================================
-- MATERIALS TABLE (for future use)
-- ============================================
CREATE TABLE IF NOT EXISTS materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  site_id UUID REFERENCES sites(id) ON DELETE SET NULL,
  
  name VARCHAR(255) NOT NULL,
  unit VARCHAR(50),
  quantity DECIMAL(10,2) DEFAULT 0,
  rate DECIMAL(10,2) DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_materials_user_id ON materials(user_id);
CREATE INDEX idx_materials_site_id ON materials(site_id);

-- ============================================
-- VENDORS TABLE (for future use)
-- ============================================
CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  name VARCHAR(255) NOT NULL,
  company VARCHAR(255),
  phone VARCHAR(20),
  email VARCHAR(255),
  address TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vendors_user_id ON vendors(user_id);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- Sites Policies
CREATE POLICY "Users can view their own sites"
  ON sites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sites"
  ON sites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sites"
  ON sites FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sites"
  ON sites FOR DELETE
  USING (auth.uid() = user_id);

-- Workers Policies
CREATE POLICY "Users can view their own workers"
  ON workers FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workers"
  ON workers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workers"
  ON workers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workers"
  ON workers FOR DELETE
  USING (auth.uid() = user_id);

-- Attendance Policies
CREATE POLICY "Users can view their own attendance"
  ON attendance FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own attendance"
  ON attendance FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own attendance"
  ON attendance FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own attendance"
  ON attendance FOR DELETE
  USING (auth.uid() = user_id);

-- Materials Policies
CREATE POLICY "Users can view their own materials"
  ON materials FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own materials"
  ON materials FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own materials"
  ON materials FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own materials"
  ON materials FOR DELETE
  USING (auth.uid() = user_id);

-- Vendors Policies
CREATE POLICY "Users can view their own vendors"
  ON vendors FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own vendors"
  ON vendors FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own vendors"
  ON vendors FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own vendors"
  ON vendors FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables
CREATE TRIGGER update_sites_updated_at
  BEFORE UPDATE ON sites
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workers_updated_at
  BEFORE UPDATE ON workers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_updated_at
  BEFORE UPDATE ON attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_materials_updated_at
  BEFORE UPDATE ON materials
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vendors_updated_at
  BEFORE UPDATE ON vendors
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SAMPLE DATA (OPTIONAL - for testing)
-- ============================================

-- Insert sample sites (replace USER_ID with actual user UUID)
/*
INSERT INTO sites (user_id, name, location) VALUES
  ('USER_ID', 'Wadhwa Wise City', 'Mumbai'),
  ('USER_ID', 'Lodha Crown', 'Thane'),
  ('USER_ID', 'Godrej Properties', 'Pune');
*/

-- Insert sample workers (replace USER_ID and SITE_ID with actual UUIDs)
/*
INSERT INTO workers (user_id, site_id, code, name, trade, rate, status, join_date) VALUES
  ('USER_ID', 'SITE_ID', 'UA-00004', 'JAHIRUL Shaikh', 'Supervisor', 32000, 'active', '2024-01-01'),
  ('USER_ID', 'SITE_ID', 'UA-00025', 'Nazrul Sekh', 'M/C', 195, 'active', '2024-02-15');
*/
