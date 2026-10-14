-- Pull Up: step 19 (things you have in common: school, college, field, industry, hometown, languages).
-- Safe to run more than once.
alter table public.profiles add column if not exists high_school text check (high_school is null or char_length(high_school) <= 60);
alter table public.profiles add column if not exists college text check (college is null or char_length(college) <= 60);
alter table public.profiles add column if not exists studied text check (studied is null or char_length(studied) <= 60);
alter table public.profiles add column if not exists industry text check (industry is null or char_length(industry) <= 60);
alter table public.profiles add column if not exists hometown text check (hometown is null or char_length(hometown) <= 60);
alter table public.profiles add column if not exists languages text check (languages is null or char_length(languages) <= 60);
