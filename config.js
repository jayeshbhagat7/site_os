/**
 * SiteOS Configuration
 * 
 * This file is deployed alongside index.html on GitHub Pages.
 * 
 * IMPORTANT: Keep this repository PRIVATE.
 * If you ever make the repo public, immediately:
 * 1. Rotate your Supabase service_role key in Supabase Dashboard → Settings → API
 * 2. Update this file with the new key
 * 
 * The anon key is safe for client-side use (it respects Row Level Security).
 * The service_role key bypasses RLS — it's used only for admin operations
 * (creating users, resetting passwords, changing emails).
 */
window.__SITEOS_CONFIG__ = {
  SUPABASE_URL: "https://nixusvqbslokiexxxtic.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5peHVzdnFic2xva2lleHh4dGljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0NzIsImV4cCI6MjA4ODQ1OTQ3Mn0.DyFJ48Iryl5cSKB1fZbuNdcge30y0vevEKaR2UyKaLQ",
  SUPABASE_SERVICE_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5peHVzdnFic2xva2lleHh4dGljIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg4MzQ3MiwiZXhwIjoyMDg4NDU5NDcyfQ.wJ8psPHNvrAQSPtx0n2AL2WIsqqzWiqr78zSthRnYmI"
};
