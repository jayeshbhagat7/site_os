# SiteOS - GitHub Integration & Deployment Guide

## 📋 Overview
This guide helps you set up GitHub version control for SiteOS and deploy it online using GitHub Pages, Netlify, or Vercel.

---

## 🚀 Quick Start: GitHub Setup

### Step 1: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in
2. Click **"New Repository"** (green button)
3. Fill in:
   - **Repository name**: `siteos-construction-erp`
   - **Description**: "SiteOS - Construction ERP for managing workers, sites, and attendance"
   - **Visibility**: Private (recommended) or Public
   - ✅ Check "Add a README file"
4. Click **"Create repository"**

### Step 2: Initialize Local Git

Open terminal in your project folder and run:

```bash
# Initialize git repository
git init

# Add all files
git add .

# Create first commit
git commit -m "Initial commit: SiteOS v3 with bug fixes"

# Add GitHub remote (replace YOUR_USERNAME and REPO_NAME)
git remote add origin https://github.com/YOUR_USERNAME/siteos-construction-erp.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Regular Updates

Every time you make changes:

```bash
# Check what changed
git status

# Add changed files
git add .

# Commit with message
git commit -m "Description of changes"

# Push to GitHub
git push
```

---

## 🌐 Online Deployment Options

### Option 1: GitHub Pages (Simplest - Free)

**Perfect for single HTML file apps**

1. Go to your GitHub repository
2. Click **Settings** → **Pages**
3. Under "Source", select **main branch**
4. Click **Save**
5. Your site will be live at: `https://YOUR_USERNAME.github.io/siteos-construction-erp/`

**Note**: You need to update Supabase URL configuration in the HTML file.

---

### Option 2: Netlify (Recommended - Free)

**Best for production deployment with custom domain**

#### Setup Steps:

1. **Create Netlify Account**
   - Go to [netlify.com](https://netlify.com)
   - Sign up with GitHub account

2. **Deploy from GitHub**
   - Click **"Add new site"** → **"Import an existing project"**
   - Select **GitHub**
   - Choose your `siteos-construction-erp` repository
   - Build settings:
     - **Build command**: Leave empty (static site)
     - **Publish directory**: `/` (root)
   - Click **Deploy**

3. **Configure Environment Variables** (if needed)
   - Go to **Site settings** → **Environment variables**
   - Add:
     - `SUPABASE_URL`: Your Supabase project URL
     - `SUPABASE_ANON_KEY`: Your Supabase anon key

4. **Custom Domain** (Optional)
   - Go to **Domain settings**
   - Add your custom domain
   - Follow DNS configuration steps

**Your site URL**: `https://your-site-name.netlify.app`

---

### Option 3: Vercel (Alternative - Free)

1. Go to [vercel.com](https://vercel.com)
2. Sign up with GitHub
3. Click **"New Project"**
4. Import your `siteos-construction-erp` repository
5. Click **Deploy**

**Your site URL**: `https://your-project.vercel.app`

---

## 🔧 Supabase Configuration

### Step 1: Get Supabase Credentials

1. Go to [supabase.com](https://supabase.com)
2. Create new project (if not already created)
3. Go to **Project Settings** → **API**
4. Copy:
   - **Project URL**
   - **Anon/Public Key**

### Step 2: Run Database Schema

1. In Supabase dashboard, go to **SQL Editor**
2. Open `supabase_schema.sql` file
3. Copy and paste entire SQL code
4. Click **Run**
5. Verify tables were created in **Table Editor**

### Step 3: Update HTML File

Replace placeholders in `siteos_v3_fixed.html`:

```javascript
// Find these lines and replace:
const SUPABASE_URL = 'YOUR_SUPABASE_URL'; 
// Replace with: 'https://xxxxx.supabase.co'

const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
// Replace with: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

---

## 📁 Recommended Project Structure

```
siteos-construction-erp/
│
├── index.html              # Main app file (renamed from siteos_v3_fixed.html)
├── README.md               # Project documentation
├── .gitignore              # Files to ignore in git
├── SETUP.md                # This setup guide
│
├── database/
│   └── schema.sql          # Supabase database schema
│
├── docs/
│   ├── DEPLOYMENT.md       # Deployment instructions
│   └── CHANGELOG.md        # Version history
│
└── assets/                 # Future: images, icons, etc.
```

---

## 🔐 .gitignore File

Create `.gitignore` file to exclude sensitive data:

```gitignore
# Environment files
.env
.env.local

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
npm-debug.log*

# Temporary files
*.tmp
temp/
```

---

## 📝 README.md Template

Create `README.md` in your repository:

```markdown
# SiteOS - Construction ERP

Modern construction site management system for tracking workers, attendance, and site operations.

## Features

- 👷 Worker Management (Registration, GTV, Status tracking)
- 📊 Multi-site Support
- 📅 Attendance Tracking
- 🔐 Secure Authentication
- 📱 Mobile Responsive

## Tech Stack

- **Frontend**: React (CDN), TailwindCSS
- **Backend**: Supabase (PostgreSQL + Auth)
- **Deployment**: Netlify / Vercel / GitHub Pages

## Setup

1. Clone repository
2. Configure Supabase credentials in `index.html`
3. Run database schema from `database/schema.sql`
4. Deploy to hosting platform

## Development

```bash
# Start local development
# Simply open index.html in browser

# Or use a local server
npx serve
```

## Deployment

See [SETUP.md](SETUP.md) for detailed deployment instructions.

## License

Private - Umiya Associates
```

---

## 🐛 Common Issues & Fixes

### Issue 1: "No workers found" Error

**Cause**: Workers not filtered by user_id or site not selected

**Fix**: Check console for errors, ensure `user_id` is properly set in queries

---

### Issue 2: CORS Errors

**Cause**: Trying to access external APIs (like Anthropic) from browser

**Fix**: Remove any API calls to anthropic.com - those were debugging artifacts

---

### Issue 3: Supabase Connection Failed

**Cause**: Invalid credentials or RLS policies blocking access

**Fix**: 
1. Verify Supabase URL and key
2. Check RLS policies are enabled
3. Ensure user is authenticated

---

## 🔄 Version Control Best Practices

### Commit Message Format

```bash
# Feature additions
git commit -m "feat: Add worker GTV functionality"

# Bug fixes
git commit -m "fix: Resolve workers not loading issue"

# UI improvements
git commit -m "ui: Improve worker card layout"

# Database changes
git commit -m "db: Add attendance tracking table"

# Documentation
git commit -m "docs: Update deployment guide"
```

### Branching Strategy

```bash
# Create feature branch
git checkout -b feature/attendance-module

# Work on feature...
git add .
git commit -m "feat: Implement attendance marking"

# Merge to main
git checkout main
git merge feature/attendance-module
git push
```

---

## 📊 Monitoring & Analytics (Optional)

### Add Google Analytics

Add before `</head>` tag:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

---

## 🎯 Next Steps

1. ✅ Set up GitHub repository
2. ✅ Deploy to Netlify/Vercel
3. ✅ Configure Supabase database
4. ✅ Test authentication flow
5. ✅ Add workers and verify data flow
6. ⏳ Implement attendance module
7. ⏳ Add material tracking
8. ⏳ Create reports & analytics

---

## 📞 Support

For issues or questions:
- Check console for errors
- Review Supabase logs
- Verify RLS policies
- Check network tab for failed requests

---

## 🔗 Useful Links

- [Supabase Docs](https://supabase.com/docs)
- [React Documentation](https://react.dev)
- [TailwindCSS Docs](https://tailwindcss.com/docs)
- [Netlify Docs](https://docs.netlify.com)
- [GitHub Pages Guide](https://pages.github.com)

---

**Last Updated**: April 24, 2026
**Version**: 3.0 (Fixed)
**Author**: Jayesh Bhagat @ Umiya Associates
