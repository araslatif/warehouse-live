-- V61 REQUIRED REALTIME + CONCURRENT SAVE UPDATE
-- Run once in Supabase SQL Editor, then deploy the updated public folder and refresh ALL devices.
-- Preserves existing warehouse state and markets. Uses the application's existing no-login model.
begin;
create table if not exists public.warehouse_sync_operations_v61 (
  operation_id text primary key,
  revision bigint not null,
  committed_at timestamptz not null default now()
);
alter table public.warehouse_sync_operations_v61 enable row level security;
revoke all on public.warehouse_sync_operations_v61 from anon, authenticated;

create or replace function public.get_warehouse_sync_snapshot_v61(p_operation_ids text[] default '{}')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare result jsonb;
begin
  if coalesce(cardinality(p_operation_ids),0)>500 then raise exception 'Too many operations'; end if;
  select jsonb_build_object('state',w.state,'revision',w.revision,'applied_ids',
    coalesce((select jsonb_agg(o.operation_id) from public.warehouse_sync_operations_v61 o
      where o.operation_id=any(p_operation_ids)),'[]'::jsonb))
    into result from public.warehouse_state w where w.id=1;
  if result is null then raise exception 'Warehouse state row 1 is missing'; end if;
  return result;
end $$;

create or replace function public.save_warehouse_state_v61(p_state jsonb,p_expected_revision bigint,p_operation_ids text[])
returns bigint language plpgsql security definer set search_path = public, pg_temp as $$
declare current_revision bigint; next_revision bigint;
begin
  if jsonb_typeof(p_state) is distinct from 'object'
    or jsonb_typeof(p_state->'zones') is distinct from 'array'
    or jsonb_typeof(p_state->'zoneMarkets') is distinct from 'object' then raise exception 'Invalid warehouse state'; end if;
  if p_operation_ids is null or cardinality(p_operation_ids)<1 or cardinality(p_operation_ids)>500
    or exists(select 1 from unnest(p_operation_ids) x where x is null or length(x)>200) then
    raise exception 'Invalid operation IDs'; end if;
  select revision into current_revision from public.warehouse_state where id=1 for update;
  if current_revision is null then raise exception 'Warehouse state row 1 is missing'; end if;
  if p_expected_revision is null or current_revision<>p_expected_revision or exists(
    select 1 from public.warehouse_sync_operations_v61 where operation_id=any(p_operation_ids)) then
    raise exception 'SYNC_CONFLICT: refresh and retry' using errcode='40001';
  end if;
  update public.warehouse_state set state=p_state, revision=revision+1, updated_at=now()
    where id=1 returning revision into next_revision;
  insert into public.warehouse_sync_operations_v61(operation_id,revision)
    select distinct x,next_revision from unnest(p_operation_ids) x;
  return next_revision;
end $$;
revoke all on function public.get_warehouse_sync_snapshot_v61(text[]) from public;
revoke all on function public.save_warehouse_state_v61(jsonb,bigint,text[]) from public;
grant execute on function public.get_warehouse_sync_snapshot_v61(text[]) to anon,authenticated;
grant execute on function public.save_warehouse_state_v61(jsonb,bigint,text[]) to anon,authenticated;
-- Prevent old app versions from overwriting a newer device's work with a stale full-state save.
create or replace function public.save_warehouse_state(p_state jsonb)
returns bigint language plpgsql security definer set search_path = public, pg_temp as $$
begin raise exception 'Update this app to V61 and refresh this device before saving'; end $$;

do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
    and schemaname='public' and tablename='warehouse_state') then
    alter publication supabase_realtime add table public.warehouse_state;
  end if;
end $$;
notify pgrst,'reload schema';
commit;
