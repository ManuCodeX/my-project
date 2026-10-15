-- Pull Up: step 20 (tag a reel with "I'll be at this event" + push notification subscriptions).
-- Safe to run more than once.
alter table public.posts add column if not exists event_id text check (event_id is null or char_length(event_id) <= 80);
create index if not exists posts_event_idx on public.posts (event_id) where event_id is not null;

create table if not exists public.push_subs (
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
alter table public.push_subs enable row level security;
drop policy if exists push_subs_own on public.push_subs;
create policy push_subs_own on public.push_subs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
