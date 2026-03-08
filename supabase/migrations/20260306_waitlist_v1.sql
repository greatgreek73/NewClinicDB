do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'patients'
      and column_name = 'priority_bucket'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'patients'
      and column_name = 'waitlist_stage'
  ) then
    alter table public.patients
      rename column priority_bucket to waitlist_stage;
  end if;
end $$;

alter table public.patients
  add column if not exists waitlist_order integer;

update public.patients
set waitlist_stage = null,
    waitlist_order = null;
