-- Pull Up: step 7 (real ride requests). Safe to run more than once.
-- Run PART A, wait for "Success", then PART B as a separate query. Run after steps 2 to 6.

-- ===================== PART A =====================
create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null,
  rider_id uuid not null,
  friend jsonb,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  unique (plan_id, rider_id)
);
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'requests_plan_id_fkey') then
    alter table public.requests add constraint requests_plan_id_fkey foreign key (plan_id) references public.plans(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'requests_rider_id_fkey') then
    alter table public.requests add constraint requests_rider_id_fkey foreign key (rider_id) references public.profiles(id) on delete cascade;
  end if;
end $$;
alter table public.requests enable row level security;

drop policy if exists "requests: rider reads own" on public.requests;
create policy "requests: rider reads own" on public.requests for select to authenticated using (rider_id = auth.uid());
drop policy if exists "requests: host reads for own plans" on public.requests;
create policy "requests: host reads for own plans" on public.requests for select to authenticated
  using (exists (select 1 from public.plans p where p.id = requests.plan_id and p.host_id = auth.uid()));
drop policy if exists "requests: rider creates" on public.requests;
create policy "requests: rider creates" on public.requests for insert to authenticated
  with check (rider_id = auth.uid() and status = 'pending'
    and exists (select 1 from public.plans p where p.id = plan_id and p.active and p.expires_at > now() and p.host_id <> auth.uid()));
drop policy if exists "requests: rider updates own" on public.requests;
create policy "requests: rider updates own" on public.requests for update to authenticated
  using (rider_id = auth.uid() and status in ('pending','accepted'))
  with check (rider_id = auth.uid() and status in ('pending','cancelled'));
drop policy if exists "requests: host decides" on public.requests;
create policy "requests: host decides" on public.requests for update to authenticated
  using (exists (select 1 from public.plans p where p.id = requests.plan_id and p.host_id = auth.uid()))
  with check (status in ('accepted','declined') and exists (select 1 from public.plans p where p.id = requests.plan_id and p.host_id = auth.uid()));
drop policy if exists "requests: rider deletes own" on public.requests;
create policy "requests: rider deletes own" on public.requests for delete to authenticated using (rider_id = auth.uid());

-- ===================== PART B (run as a separate query) =====================
-- A host can see the profile and photo of riders who requested his plan.
drop policy if exists "profiles: read riders who requested my plans" on public.profiles;
create policy "profiles: read riders who requested my plans" on public.profiles for select to authenticated
  using (exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id where r.rider_id = profiles.id and p.host_id = auth.uid()));

drop policy if exists "avatars: read riders who requested my plans" on storage.objects;
create policy "avatars: read riders who requested my plans" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.rider_id::text = (storage.foldername(name))[1] and p.host_id = auth.uid()));

-- The plate is shown only to a rider whose request was accepted.
drop policy if exists "plan_private: accepted rider reads" on public.plan_private;
create policy "plan_private: accepted rider reads" on public.plan_private for select to authenticated
  using (exists (select 1 from public.requests r where r.plan_id = plan_private.plan_id and r.rider_id = auth.uid() and r.status = 'accepted'));
