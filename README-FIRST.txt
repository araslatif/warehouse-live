WAREHOUSE PLACEMENT - SUPABASE LIVE EDITION
===========================================

This edition does NOT use SQLite, Python server, port 8081, LAN IP, or firewall rules.
All devices use the same Supabase cloud database and receive live updates.

ONLY REQUIRED SETUP
1. Create a free Supabase project at https://supabase.com/
2. Open SQL Editor, paste the COMPLETE contents of SUPABASE_SETUP_COMPLETE.sql, and click Run.
   It creates the database, Realtime setup, security policies, save function, and imports all 3,893 markets.
3. In Supabase Project Settings -> API, copy:
   - Project URL
   - anon/public key (NOT service_role)
4. Run SET_SUPABASE_CONFIG.bat and paste those two values.
5. Upload the contents of the public folder to a static host such as Netlify, Cloudflare Pages, or Vercel.

NETLIFY SIMPLE DEPLOY
- Sign in to Netlify.
- Use the manual/drag-and-drop deploy and upload the public folder.
- Netlify gives you an HTTPS link. Everyone opening that link shares the same live Supabase data.

SECURITY NOTE
The included setup intentionally allows anyone who has the app to save warehouse layout changes, matching the current no-login behavior. Reads use RLS and writes are only exposed through the validated save_warehouse_state RPC. If you later want Admin/Employee logins, add Supabase Auth and role-based policies.

FILES
public/index.html              App UI + Supabase Realtime integration
public/supabase-config.js     Your Supabase URL/key
SUPABASE_SETUP_COMPLETE.sql   One-run database/schema/market import setup
SET_SUPABASE_CONFIG.bat       Easy Windows config helper
PREVIEW_LOCAL.bat             Optional local preview only
Bruska-Market-Directory-3893.csv Original market source data
