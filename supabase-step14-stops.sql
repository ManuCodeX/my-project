-- Pull Up: step 14 (up to 3 real stops per plan). Safe to run more than once.
alter table public.plans add column if not exists stops jsonb;
