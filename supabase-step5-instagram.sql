-- Pull Up: optional Instagram handle on profiles. Safe to run more than once.
-- Paste into Supabase > SQL Editor > New query, then Run.
-- Hosts with a live plan are already readable by riders, so their handle shows with the rest of their profile.
alter table public.profiles add column if not exists instagram text;
alter table public.profiles drop constraint if exists profiles_instagram_format;
alter table public.profiles add constraint profiles_instagram_format check (instagram is null or instagram ~ '^[A-Za-z0-9._]{1,30}$');
