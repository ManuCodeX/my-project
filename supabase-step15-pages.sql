-- Pull Up: step 15 (host page: car photo + 24-hour story posts). Run PART A, then PART B as a separate query.

-- ===== PART A =====
alter table public.profiles add column if not exists car_photo_path text;

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  path text not null,
  kind text not null check (kind in ('image','video')),
  caption text check (caption is null or char_length(caption) <= 140),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index if not exists posts_host_idx on public.posts (host_id, expires_at);
alter table public.posts enable row level security;

drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts for select to anon, authenticated using (expires_at > now());
drop policy if exists posts_read_own on public.posts;
create policy posts_read_own on public.posts for select to authenticated using (host_id = auth.uid());
drop policy if exists posts_insert on public.posts;
create policy posts_insert on public.posts for insert to authenticated with check (host_id = auth.uid());
drop policy if exists posts_delete on public.posts;
create policy posts_delete on public.posts for delete to authenticated using (host_id = auth.uid());

-- ===== PART B (separate query) =====
-- The vlogs bucket now also holds photos (car photo and story pictures).
update storage.buckets
set allowed_mime_types = array['video/mp4','video/quicktime','video/webm','video/3gpp','image/jpeg','image/png','image/webp','image/heic'],
    file_size_limit = 47185920
where id = 'vlogs';
