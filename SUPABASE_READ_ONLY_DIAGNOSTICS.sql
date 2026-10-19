-- Read-only diagnostics for warehouse-live / V100.
-- Run against the intended project gtdcyiunzpenvkwqgxga from Supabase SQL Editor.
-- This script never updates application data or database configuration.
BEGIN READ ONLY;

-- Connection, database size, and current effective timeout (SQL Editor role only).
SELECT now() AS captured_at,
       current_database() AS database_name,
       current_user AS sql_editor_role,
       current_setting('statement_timeout') AS sql_editor_statement_timeout,
       pg_size_pretty(pg_database_size(current_database())) AS database_size;

-- Connection/transaction pressure without exposing SQL text or record values.
SELECT state, wait_event_type, wait_event, backend_type,
       count(*) AS connections,
       max(now() - xact_start) FILTER (WHERE xact_start IS NOT NULL) AS oldest_transaction,
       max(now() - query_start) FILTER (WHERE query_start IS NOT NULL) AS oldest_query
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state, wait_event_type, wait_event, backend_type
ORDER BY connections DESC;

-- Blocking pairs only; no query text is selected.
SELECT blocked.pid AS blocked_pid,
       blocked.application_name AS blocked_application,
       blocked.wait_event_type,
       blocked.wait_event,
       now() - blocked.query_start AS blocked_for,
       blocker.pid AS blocker_pid,
       blocker.application_name AS blocker_application,
       blocker.state AS blocker_state,
       now() - blocker.xact_start AS blocker_transaction_age
FROM pg_stat_activity AS blocked
CROSS JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS p(blocker_pid)
JOIN pg_stat_activity AS blocker ON blocker.pid = p.blocker_pid
WHERE blocked.datname = current_database();

-- Estimated size/row counts for synchronization tables; exact counts are omitted
-- to avoid full-table scans while the database may be under load.
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       c.reltuples::bigint AS estimated_rows,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r','p')
  AND c.relname IN ('warehouse_state','warehouse_sync_operations_v61',
                     'warehouse_sync_pages100','warehouse_sync_head100',
                     'warehouse_patch_parts100')
ORDER BY c.relname;

-- Function signatures, SECURITY DEFINER status, per-function settings, and
-- EXECUTE grants for the public client roles.
SELECT p.oid::regprocedure AS function_signature,
       p.prosecdef AS security_definer,
       p.proconfig AS function_settings,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_warehouse_manifest100','get_warehouse_pages100',
                    'stage_warehouse_patch100','save_warehouse_patch100',
                    'warehouse_materialize100','warehouse_projection_trigger100')
ORDER BY p.proname, p.oid::regprocedure::text;

-- Role-level defaults. These are not the same as the SQL Editor's own timeout.
SELECT rolname, rolconfig
FROM pg_roles
WHERE rolname IN ('anon','authenticated','authenticator','postgres')
ORDER BY rolname;

-- RLS and policies for the V100 sync tables.
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('warehouse_sync_pages100','warehouse_sync_head100','warehouse_patch_parts100');

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('warehouse_sync_pages100','warehouse_sync_head100','warehouse_patch_parts100')
ORDER BY tablename, policyname;

COMMIT;
