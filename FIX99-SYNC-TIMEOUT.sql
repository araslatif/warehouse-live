-- V99: allow large sync snapshots to finish. No data or roles are reset.
ALTER FUNCTION public.get_warehouse_sync_snapshot_v61(text[]) SET statement_timeout TO '60s';
ALTER FUNCTION public.save_warehouse_state_v61(jsonb,bigint,text[]) SET statement_timeout TO '60s';
NOTIFY pgrst, 'reload schema';
SELECT proname,proconfig FROM pg_proc WHERE oid IN (
 'public.get_warehouse_sync_snapshot_v61(text[])'::regprocedure,
 'public.save_warehouse_state_v61(jsonb,bigint,text[])'::regprocedure);
