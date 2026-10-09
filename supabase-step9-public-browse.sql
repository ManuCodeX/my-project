-- Pull Up: step 9. Let people who are NOT signed in browse live plans. Safe to run more than once.
-- Visible without signing in: a host's first name, age, gender, photo, Instagram name, car, plan details and vlog,
-- but only while that host has a live plan. The plate stays private. Requests, follows and chat still need sign-in.
-- To turn this off again, run supabase-step9-undo.sql.

drop policy if exists "plans: anyone reads live" on public.plans;
create policy "plans: anyone reads live" on public.plans for select to anon
  using (active and expires_at > now());

drop policy if exists "profiles: anyone reads hosts with live plans" on public.profiles;
create policy "profiles: anyone reads hosts with live plans" on public.profiles for select to anon
  using (exists (select 1 from public.plans p where p.host_id = profiles.id and p.active and p.expires_at > now()));

drop policy if exists "avatars: anyone reads hosts with live plans" on storage.objects;
create policy "avatars: anyone reads hosts with live plans" on storage.objects for select to anon
  using (bucket_id = 'avatars' and exists (select 1 from public.plans p
    where p.host_id::text = (storage.foldername(name))[1] and p.active and p.expires_at > now()));

drop policy if exists "vlogs: anyone reads hosts with live plans" on storage.objects;
create policy "vlogs: anyone reads hosts with live plans" on storage.objects for select to anon
  using (bucket_id = 'vlogs' and exists (select 1 from public.plans p
    where p.host_id::text = (storage.foldername(name))[1] and p.active and p.expires_at > now()));
