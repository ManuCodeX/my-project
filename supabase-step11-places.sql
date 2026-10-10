-- Pull Up: step 11 (real pickup spot and next stop). Safe to run more than once.
alter table public.plans add column if not exists pickup_lat double precision;
alter table public.plans add column if not exists pickup_lng double precision;
alter table public.plans add column if not exists stop_name text;
alter table public.plans add column if not exists stop_lat double precision;
alter table public.plans add column if not exists stop_lng double precision;
