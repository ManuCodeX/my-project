-- Pull Up: step 8 (chat after a match). Safe to run more than once. Run after step 7.
-- Only the rider and the host of an ACCEPTED request can read or write messages.

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.requests(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists messages_request_idx on public.messages (request_id, created_at);
alter table public.messages enable row level security;

drop policy if exists "messages: participants read" on public.messages;
create policy "messages: participants read" on public.messages for select to authenticated
  using (exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.id = messages.request_id and r.status = 'accepted' and (r.rider_id = auth.uid() or p.host_id = auth.uid())));

drop policy if exists "messages: participants send" on public.messages;
create policy "messages: participants send" on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and exists (select 1 from public.requests r join public.plans p on p.id = r.plan_id
    where r.id = request_id and r.status = 'accepted' and p.active and p.expires_at > now()
      and (r.rider_id = auth.uid() or p.host_id = auth.uid())));
