-- Step 13: real events. Run PART A first, then PART B as a separate query.

-- ===== PART A =====
create table if not exists public.events (
  id text primary key,
  name text not null check (char_length(name) between 2 and 80),
  venue text not null check (char_length(venue) between 2 and 80),
  lat double precision not null,
  lng double precision not null,
  starts_at timestamptz not null,
  source text not null default 'host',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.events enable row level security;
drop policy if exists events_read on public.events;
create policy events_read on public.events for select using (true);
drop policy if exists events_insert on public.events;
create policy events_insert on public.events for insert to authenticated with check (created_by = auth.uid());

-- ===== PART B (separate query) =====
alter table public.plans drop constraint if exists plans_event_check;
alter table public.going drop constraint if exists going_event_check;
