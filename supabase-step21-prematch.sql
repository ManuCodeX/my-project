-- Pull Up: step 21 (fix re-requesting after cancelling, chat before a match, voice notes, mood, memories).
-- Run PART A, then PART B as a separate query. Safe to run more than once.

-- ===== PART A =====
-- A rider who cancelled can ask again (this was the "row violates row-level security" error on Request this ride).
drop policy if exists "requests: rider updates own" on public.requests;
create policy "requests: rider updates own" on public.requests for update to authenticated
  using (rider_id = auth.uid() and status in ('pending','accepted','cancelled'))
  with check (rider_id = auth.uid() and status in ('pending','cancelled'));

alter table public.requests add column if not exists mood text check (mood is null or char_length(mood) <= 60);
alter table public.messages add column if not exists audio_path text;
alter table public.messages add column if not exists kind text not null default 'text';
alter table public.messages alter column body drop not null;

create table if not exists public.memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  path text not null,
  kind text not null check (kind in ('image','video')),
  caption text check (caption is null or char_length(caption) <= 140),
  created_at timestamptz not null default now()
);
create index if not exists memories_user_idx on public.memories (user_id, created_at desc);
alter table public.memories enable row level security;
drop policy if exists memories_own on public.memories;
create policy memories_own on public.memories for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Chat opens as soon as a rider asks (pending), so you can talk before it is official. Stays open after acceptance.
drop policy if exists "messages: participants read" on public.messages;
create policy "messages: participants read" on public.messages for select to authenticated
  using (exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.id = messages.request_id and r.status in ('pending','accepted') and (r.rider_id = auth.uid() or p.host_id = auth.uid())));
drop policy if exists "messages: participants send" on public.messages;
create policy "messages: participants send" on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.id = request_id and r.status in ('pending','accepted') and p.active and p.expires_at > now()
      and (r.rider_id = auth.uid() or p.host_id = auth.uid())));

-- ===== PART B (run as a separate query) =====
-- Private bucket for voice notes. Only the two people on the request can upload or hear them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice', 'voice', false, 3000000, array['audio/webm','audio/mp4','audio/mpeg','audio/ogg','audio/aac','audio/x-m4a'])
on conflict (id) do update set file_size_limit = 3000000, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "voice: participants upload" on storage.objects;
create policy "voice: participants upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'voice' and exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.id::text = (storage.foldername(name))[1] and (r.rider_id = auth.uid() or p.host_id = auth.uid())));
drop policy if exists "voice: participants read" on storage.objects;
create policy "voice: participants read" on storage.objects for select to authenticated
  using (bucket_id = 'voice' and exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.id::text = (storage.foldername(name))[1] and (r.rider_id = auth.uid() or p.host_id = auth.uid())));
