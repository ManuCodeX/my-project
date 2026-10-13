-- Pull Up: step 16 (rider/host role, rider heat spots, rider story visibility).
-- Run PART A first, then PART B as a separate query.

-- ===== PART A =====
alter table public.profiles add column if not exists role text check (role in ('rider','host'));

-- Riders who opt in leave one rough (about 300 m) location dot that expires after 30 minutes.
create table if not exists public.rider_pings (
  rider_id uuid primary key references auth.users(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  updated_at timestamptz not null default now()
);
alter table public.rider_pings enable row level security;
drop policy if exists pings_own_write on public.rider_pings;
create policy pings_own_write on public.rider_pings for all to authenticated
  using (rider_id = auth.uid()) with check (rider_id = auth.uid());

-- Hosts see only counts per grid cell. Never who, never exact positions.
create or replace function public.rider_heat()
returns table (lat double precision, lng double precision, n bigint)
language sql security definer set search_path = public as $$
  select round(lat / 0.004) * 0.004 as lat, round(lng / 0.004) * 0.004 as lng, count(*) as n
  from public.rider_pings
  where updated_at > now() - interval '30 minutes'
  group by 1, 2
$$;
revoke all on function public.rider_heat() from public, anon;
grant execute on function public.rider_heat() to authenticated;

-- ===== PART B (separate query) =====
-- A story post is visible to: its owner, anyone when the owner is a host with a live plan,
-- and a host when the owner is a rider who has asked for (or been accepted on) his plan.
drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts for select to anon, authenticated using (
  expires_at > now() and (
    host_id = auth.uid()
    or exists (select 1 from public.plans p where p.host_id = posts.host_id and p.active and p.expires_at > now())
    or exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
               where r.rider_id = posts.host_id and p.host_id = auth.uid() and r.status in ('pending','accepted'))
  )
);

drop policy if exists "vlogs: hosts read requesting riders" on storage.objects;
create policy "vlogs: hosts read requesting riders" on storage.objects for select to authenticated
  using (bucket_id = 'vlogs' and exists (
    select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.rider_id::text = (storage.foldername(name))[1] and p.host_id = auth.uid() and r.status in ('pending','accepted')));
