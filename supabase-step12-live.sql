-- Pull Up: step 12 (live car location). Safe to run more than once. Run PART A, then PART B as a separate query.

-- ===================== PART A =====================
create table if not exists public.live_pos (
  plan_id uuid primary key references public.plans(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading real,
  updated_at timestamptz not null default now()
);
alter table public.live_pos enable row level security;

-- ===================== PART B (run as a separate query) =====================
-- The host writes his own car's position. Only he and riders he ACCEPTED can read it.
drop policy if exists "live_pos: host inserts" on public.live_pos;
create policy "live_pos: host inserts" on public.live_pos for insert to authenticated
  with check (exists (select 1 from public.plans p where p.id = plan_id and p.host_id = auth.uid() and p.active));
drop policy if exists "live_pos: host updates" on public.live_pos;
create policy "live_pos: host updates" on public.live_pos for update to authenticated
  using (exists (select 1 from public.plans p where p.id = live_pos.plan_id and p.host_id = auth.uid()))
  with check (exists (select 1 from public.plans p where p.id = plan_id and p.host_id = auth.uid()));
drop policy if exists "live_pos: host deletes" on public.live_pos;
create policy "live_pos: host deletes" on public.live_pos for delete to authenticated
  using (exists (select 1 from public.plans p where p.id = live_pos.plan_id and p.host_id = auth.uid()));
drop policy if exists "live_pos: host and accepted riders read" on public.live_pos;
create policy "live_pos: host and accepted riders read" on public.live_pos for select to authenticated
  using (
    exists (select 1 from public.plans p where p.id = live_pos.plan_id and p.host_id = auth.uid())
    or exists (select 1 from public.requests r where r.plan_id = live_pos.plan_id and r.rider_id = auth.uid() and r.status = 'accepted')
  );
