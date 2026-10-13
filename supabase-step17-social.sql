-- Pull Up: step 17 (reels from followed people, friends = follow each other, friends near you, car on profile).
-- Run PART A first, then PART B as a separate query.

-- ===== PART A =====
alter table public.profiles add column if not exists car text check (car is null or char_length(car) <= 60);
alter table public.profiles add column if not exists car_color text check (car_color is null or char_length(car_color) <= 30);

-- Friends only: one rough dot (about 200 m) per person who chose to share, expires after 30 minutes.
create table if not exists public.friend_pos (
  user_id uuid primary key references auth.users(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  updated_at timestamptz not null default now()
);
alter table public.friend_pos enable row level security;
drop policy if exists friend_pos_own on public.friend_pos;
create policy friend_pos_own on public.friend_pos for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Friends = people you follow who also follow you.
create or replace function public.my_friends()
returns table (friend_id uuid)
language sql security definer set search_path = public as $$
  select a.followed_id from public.follows a
  join public.follows b on b.follower_id = a.followed_id and b.followed_id = a.follower_id
  where a.follower_id = auth.uid()
$$;
revoke all on function public.my_friends() from public, anon;
grant execute on function public.my_friends() to authenticated;

create or replace function public.friends_nearby()
returns table (id uuid, first_name text, photo_path text, lat double precision, lng double precision, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select p.id, p.first_name, p.photo_path, f.lat, f.lng, f.updated_at
  from public.friend_pos f
  join public.profiles p on p.id = f.user_id
  where f.updated_at > now() - interval '30 minutes'
    and f.user_id in (select friend_id from public.my_friends())
$$;
revoke all on function public.friends_nearby() from public, anon;
grant execute on function public.friends_nearby() to authenticated;

-- ===== PART B (separate query) =====
-- You can open the profile of anyone you follow.
drop policy if exists "profiles: read people I follow" on public.profiles;
create policy "profiles: read people I follow" on public.profiles for select to authenticated
  using (id in (select followed_id from public.follows where follower_id = auth.uid()));

drop policy if exists "avatars: read people I follow" on storage.objects;
create policy "avatars: read people I follow" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] in (select followed_id::text from public.follows where follower_id = auth.uid()));

drop policy if exists "vlogs: read people I follow" on storage.objects;
create policy "vlogs: read people I follow" on storage.objects for select to authenticated
  using (bucket_id = 'vlogs' and (storage.foldername(name))[1] in (select followed_id::text from public.follows where follower_id = auth.uid()));

-- Reels: owner, any host with a live plan, a rider who asked a host you are (step 16), or anyone you follow.
drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts for select to anon, authenticated using (
  expires_at > now() and (
    host_id = auth.uid()
    or exists (select 1 from public.plans p where p.host_id = posts.host_id and p.active and p.expires_at > now())
    or exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
               where r.rider_id = posts.host_id and p.host_id = auth.uid() and r.status in ('pending','accepted'))
    or exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = posts.host_id)
  )
);
