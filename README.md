# ARAM Warehouse V91

Web and Android share the same V91 application code.

## GitHub / Cloudflare
Copy the contents directly into the existing repository root, preserve `images/`
and your live `supabase-config.js` in root and public. Commit and Push.
Build: `npm run build`. Deploy: `npx wrangler deploy`. Root: `/`.
`build.mjs` copies public assets and root images into dist; Git metadata is not published.
Check the live `/version.json` after deployment.

## V89
- Scoped full/partial backups, SHA-256 verification and selected-section restore.
- Add missing or update matching records, preserving unrelated current records.
- Local recovery snapshot before restoration; latest five retained on that device.
- Retained activity and assignment archives and before/after driver/placed snapshots.
- Daily baseline while an authorized updated app is open; manual saved lists.
- Historical PDF/CSV sources with driver/date/time/event filters.
- Large font layouts, individual column font/width, margins, padding, color and presets.

Read START_HERE_V89.txt for operation, limits and upgrade instructions.
Update all editing devices; older releases do not preserve the new history fields.
Historical collection starts with V89; no unknown past lists can be reconstructed.
Original product image binaries are not embedded in JSON backups. Preserve images/.
No SQL scripts are required for this update. Do not execute old setup/reset/import scripts.

## V90 dispatcher
Quick driver shortcuts, Auto mode, confirmed transfer while loading and an optional unnamed-driver load. See START_HERE_V90.txt.

## V91 CSV market lists
Import populated invoice CSV files, map duplicate headings, preserve all raw fields and join only those markets to live warehouse status/actions. Read START_HERE_V91.txt. The attached Total-0 example has headers only and no market rows.
