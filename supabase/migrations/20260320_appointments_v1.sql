create table if not exists public.appointments (
  id text primary key,
  patient_id text not null references public.patients (id) on delete restrict,
  start_at timestamptz not null,
  end_at timestamptz not null,
  visit_label text not null,
  room_label text null,
  notes text null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'cancelled', 'no_show')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint appointments_end_after_start check (end_at > start_at)
);

create index if not exists appointments_start_at_idx
  on public.appointments (start_at);

create index if not exists appointments_patient_id_idx
  on public.appointments (patient_id);

create index if not exists appointments_status_start_at_idx
  on public.appointments (status, start_at);
