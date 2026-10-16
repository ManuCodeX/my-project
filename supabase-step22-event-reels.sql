-- Pull Up: step 22 (reels tagged "I'll be at <event>" are visible to every signed-in person).
-- Untagged reels stay visible only to the poster, people who add them, and riders/hosts with a live link (steps 16 and 17).
-- Run PART A, then PART B as a separate query. Safe to run more than once.

-- ===== PART A =====
drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts for select to anon, authenticated using (
  expires_at > now() and (
    host_id = auth.uid()
    or (event_id is not null and auth.uid() is not null)
    or exists (select 1 from public.plans p where p.host_id = posts.host_id and p.active and p.expires_at > now())
    or exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
               where r.rider_id = posts.host_id and p.host_id = auth.uid() and r.status in ('pending','accepted'))
    or exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followed_id = posts.host_id)
  )
);

-- Who posted it (first name, role, photo path only) for every live event-tagged reel.
create or replace function public.event_reels()
returns table (post_id uuid, host_id uuid, path text, kind text, caption text, event_id text, created_at timestamptz, expires_at timestamptz,
               first_name text, role text, photo_path text)
language sql security definer set search_path = public as $$
  select p.id, p.host_id, p.path, p.kind, p.caption, p.event_id, p.created_at, p.expires_at, pr.first_name, pr.role, pr.photo_path
  from public.posts p join public.profiles pr on pr.id = p.host_id
  where auth.uid() is not null and p.event_id is not null and p.expires_at > now()
  order by p.created_at desc limit 60
$$;
revoke all on function public.event_reels() from public, anon;
grant execute on function public.event_reels() to authenticated;

-- ===== PART B (run as a separate query) =====
drop policy if exists "vlogs: read event-tagged reels" on storage.objects;
create policy "vlogs: read event-tagged reels" on storage.objects for select to authenticated
  using (bucket_id = 'vlogs' and exists (select 1 from public.posts p where p.path = name and p.event_id is not null and p.expires_at > now()));

drop policy if exists "avatars: read event reel posters" on storage.objects;
create policy "avatars: read event reel posters" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and exists (select 1 from public.posts p
    where p.host_id::text = (storage.foldername(name))[1] and p.event_id is not null and p.expires_at > now()));
