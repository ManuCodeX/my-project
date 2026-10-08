-- Pull Up: step 4 setup (vlogs). Run AFTER supabase-setup.sql and supabase-step3.sql.
-- Paste this whole file into Supabase > SQL Editor > New query, then click Run.
-- Hosts upload one short video. The bucket is private; riders can only watch a host's vlog while that
-- host has a live plan. Each host has one file (<user id>/vlog), replaced on every new plan.

alter table public.plans add column if not exists vlog_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('vlogs', 'vlogs', false, 47185920, array['video/mp4','video/quicktime','video/webm','video/3gpp'])
on conflict (id) do nothing;

create policy "vlogs: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'vlogs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "vlogs: read hosts with live plans" on storage.objects
  for select to authenticated
  using (bucket_id = 'vlogs' and exists (
    select 1 from public.plans p
    where p.host_id::text = (storage.foldername(name))[1] and p.active and p.expires_at > now()));

create policy "vlogs: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'vlogs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "vlogs: replace own" on storage.objects
  for update to authenticated
  using (bucket_id = 'vlogs' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'vlogs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "vlogs: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'vlogs' and (storage.foldername(name))[1] = auth.uid()::text);
