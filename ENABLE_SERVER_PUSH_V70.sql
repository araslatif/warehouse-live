-- Run ONCE in the Supabase SQL Editor for the project's existing database.
-- Adds notifications only. Does not replace any working save RPC or alter app data.
begin;
create or replace function public.warehouse_notify_devices_v70()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, pg_temp as $$
begin
  -- Metadata only; devices fetch current data using the existing read permissions.
  -- realtime.messages is transactional: rolled-back edits are not broadcast.
  if TG_TABLE_NAME = 'warehouse_state' then
    perform realtime.send(jsonb_build_object('revision',NEW.revision),
      'state-changed','warehouse-live',false);
  else
    perform realtime.send(jsonb_build_object('table','markets'),
      'directory-changed','warehouse-live',false);
  end if;
  return null;
exception when others then
  -- A notification outage must never break the existing working save operation.
  raise warning 'Warehouse notification deferred: %', SQLERRM;
  return null;
end $$;
revoke all on function public.warehouse_notify_devices_v70() from public;
drop trigger if exists warehouse_notify_devices_v70 on public.warehouse_state;
create trigger warehouse_notify_devices_v70 after insert or update on public.warehouse_state
for each row when (NEW.id = 1) execute function public.warehouse_notify_devices_v70();
drop trigger if exists warehouse_notify_directory_v70 on public.markets;
create trigger warehouse_notify_directory_v70 after insert or update or delete on public.markets
for each statement execute function public.warehouse_notify_devices_v70();
commit;
-- Read-only confirmation: both rows must show enabled = O.
select tgname, tgenabled as enabled from pg_trigger
where tgname in ('warehouse_notify_devices_v70','warehouse_notify_directory_v70');
