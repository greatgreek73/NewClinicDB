create table if not exists public.waiting_room_reasons (
  id text primary key,
  label text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists waiting_room_reasons_sort_order_idx
  on public.waiting_room_reasons (sort_order, created_at);

insert into public.waiting_room_reasons (
  id,
  label,
  sort_order,
  is_active
) values
  ('waiting_reason_consultation', 'Консультация', 1, true),
  ('waiting_reason_exam', 'осмотр', 2, true),
  ('waiting_reason_sutures', 'швы', 3, true),
  ('waiting_reason_argue', 'ругаться', 4, true)
on conflict (id) do nothing;

create table if not exists public.waiting_room_entries (
  id text primary key,
  entry_date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  lane text not null,
  source_type text not null,
  patient_id text null,
  display_name text not null,
  manual_surname text null,
  reason_id text null references public.waiting_room_reasons (id),
  reason_label_snapshot text not null
);

create index if not exists waiting_room_entries_entry_date_idx
  on public.waiting_room_entries (entry_date);

create index if not exists waiting_room_entries_created_at_idx
  on public.waiting_room_entries (created_at desc);
