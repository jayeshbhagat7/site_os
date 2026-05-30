/**
 * SiteOS Configuration File
 * 
 * INSTRUCTIONS:
 * 1. Copy this file to `config.js` in the same directory
 * 2. Fill in your Supabase credentials
 * 3. NEVER commit config.js to version control (it's in .gitignore)
 * 4. For production: serve config.js from your server with proper access controls
 * 
 * SECURITY NOTES:
 * - The SUPABASE_SERVICE_KEY grants FULL access to your database
 * - It bypasses ALL Row Level Security (RLS) policies
 * - In production, admin operations (user creation, password reset, email change)
 *   should be handled by a secure backend/Edge Function, NOT client-side JS
 * - The anon key is safe to expose (it's designed for client-side use with RLS)
 */
window.__SITEOS_CONFIG__ = {
  SUPABASE_URL: "https://YOUR_PROJECT_REF.supabase.co",
  SUPABASE_ANON_KEY: "YOUR_ANON_KEY_HERE",
  
  // WARNING: Only set this for local development / trusted admin environments
  // In production, use a server-side API for admin operations
  SUPABASE_SERVICE_KEY: ""
};
