-- Pull Up: step 6 (follow hosts, "I'm going" counts). Safe to run more than once.
-- Run PART A, wait for "Success", then run PART B as a separate query.

-- ===================== PART A =====================
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
alter table public.follows enable row level security;
drop policy if exists "follows: read own" on public.follows;
create policy "follows: read own" on public.follows for select to authenticated using (follower_id = auth.uid());
drop policy if exists "follows: add own" on public.follows;
create policy "follows: add own" on public.follows for insert to authenticated with check (follower_id = auth.uid());
drop policy if exists "follows: remove own" on public.follows;
create policy "follows: remove own" on public.follows for delete to authenticated using (follower_id = auth.uid());

create table if not exists public.going (
  user_id uuid not null references public.profiles(id) on delete cascade,
  event text not null check (event in ('a','b')),
  expires_at timestamptz not null default (now() + interval '12 hours'),
  primary key (user_id, event)
);
alter table public.going enable row level security;
drop policy if exists "going: read own" on public.going;
create policy "going: read own" on public.going for select to authenticated using (user_id = auth.uid());
drop policy if exists "going: add own" on public.going;
create policy "going: add own" on public.going for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "going: update own" on public.going;
create policy "going: update own" on public.going for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "going: remove own" on public.going;
create policy "going: remove own" on public.going for delete to authenticated using (user_id = auth.uid());

-- ===================== PART B (run as a separate query) =====================
-- Counts only. Nobody can see who follows a host or who is going.
create or replace function public.follower_counts(host_ids uuid[])
returns table(host_id uuid, n bigint) language sql security definer set search_path = public as $$
  select followed_id, count(*) from public.follows where followed_id = any(host_ids) group by followed_id;
$$;
create or replace function public.going_counts()
returns table(event text, n bigint) language sql security definer set search_path = public as $$
  select event, count(*) from public.going where expires_at > now() group by event;
$$;
revoke all on function public.follower_counts(uuid[]) from public, anon;
revoke all on function public.going_counts() from public, anon;
grant execute on function public.follower_counts(uuid[]) to authenticated;
grant execute on function public.going_counts() to authenticated;
