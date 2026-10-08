-- Pull Up: step 3 setup (live plans). Run AFTER supabase-setup.sql.
-- This file is safe to run more than once. If you ever see a "deadlock detected" error, wait 30 seconds and run it again.
-- Run PART A first, wait for "Success", then run PART B as a second query.

-- ===================== PART A =====================
-- Paste this whole file into Supabase > SQL Editor > New query, then click Run.
-- Hosts post a plan; any signed-in rider can see live plans. Plates live in a separate private table
-- so they are not shown to riders. Plans expire after 12 hours.

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null,
  event text not null check (event in ('a','b')),
  park_desc text not null check (char_length(park_desc) between 1 and 120),
  park_m int not null default 100,
  leaving_text text not null check (char_length(leaving_text) <= 12),
  car text not null check (char_length(car) between 1 and 60),
  color text not null check (char_length(color) between 1 and 30),
  next_venue int not null check (next_venue between 0 and 4),
  house_offered boolean not null default false,
  house_area text,
  house_idx int not null default 0 check (house_idx between 0 and 4),
  seats int not null check (seats between 1 and 6),
  friends_ok boolean not null default true,
  friend_pref text not null default 'any' check (friend_pref in ('any','women')),
  rules text[] not null default '{}',
  vibe text[] not null default '{}',
  crew jsonb not null default '[]'::jsonb check (jsonb_array_length(crew) <= 7),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '12 hours'),
  constraint plans_host_id_fkey foreign key (host_id) references public.profiles(id) on delete cascade
);
create index if not exists plans_live_idx on public.plans (active, expires_at desc);
alter table public.plans enable row level security;

drop policy if exists "plans: read live or own" on public.plans;
create policy "plans: read live or own" on public.plans
  for select to authenticated using (host_id = auth.uid() or (active and expires_at > now()));
drop policy if exists "plans: insert own" on public.plans;
create policy "plans: insert own" on public.plans
  for insert to authenticated with check (host_id = auth.uid());
drop policy if exists "plans: update own" on public.plans;
create policy "plans: update own" on public.plans
  for update to authenticated using (host_id = auth.uid()) with check (host_id = auth.uid());
drop policy if exists "plans: delete own" on public.plans;
create policy "plans: delete own" on public.plans
  for delete to authenticated using (host_id = auth.uid());

create table if not exists public.plan_private (
  plan_id uuid primary key references public.plans(id) on delete cascade,
  plate text not null check (char_length(plate) between 1 and 20)
);
alter table public.plan_private enable row level security;

drop policy if exists "plan_private: host reads" on public.plan_private;
create policy "plan_private: host reads" on public.plan_private
  for select to authenticated
  using (exists (select 1 from public.plans p where p.id = plan_private.plan_id and p.host_id = auth.uid()));
drop policy if exists "plan_private: host inserts" on public.plan_private;
create policy "plan_private: host inserts" on public.plan_private
  for insert to authenticated
  with check (exists (select 1 from public.plans p where p.id = plan_private.plan_id and p.host_id = auth.uid()));
drop policy if exists "plan_private: host updates" on public.plan_private;
create policy "plan_private: host updates" on public.plan_private
  for update to authenticated
  using (exists (select 1 from public.plans p where p.id = plan_private.plan_id and p.host_id = auth.uid()))
  with check (exists (select 1 from public.plans p where p.id = plan_private.plan_id and p.host_id = auth.uid()));

-- ===================== PART B (run as a separate query) =====================
-- Riders can see the profile (name, age, gender, vibes, photo path) of a host who has a live plan.
drop policy if exists "profiles: read hosts with live plans" on public.profiles;
create policy "profiles: read hosts with live plans" on public.profiles
  for select to authenticated
  using (exists (select 1 from public.plans p where p.host_id = profiles.id and p.active and p.expires_at > now()));

-- Riders can see the photo of a host who has a live plan.
drop policy if exists "avatars: read hosts with live plans" on storage.objects;
create policy "avatars: read hosts with live plans" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and exists (
    select 1 from public.plans p
    where p.host_id::text = (storage.foldername(name))[1] and p.active and p.expires_at > now()));
