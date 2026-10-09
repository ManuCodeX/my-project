-- Turns public browsing off again: live plans need sign-in to see.
drop policy if exists "plans: anyone reads live" on public.plans;
drop policy if exists "profiles: anyone reads hosts with live plans" on public.profiles;
drop policy if exists "avatars: anyone reads hosts with live plans" on storage.objects;
drop policy if exists "vlogs: anyone reads hosts with live plans" on storage.objects;
