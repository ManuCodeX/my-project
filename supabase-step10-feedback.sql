-- Pull Up: step 10. Save feedback and waitlist answers in Supabase (works on Vercel, Netlify or anywhere).
-- Safe to run more than once. Anyone can send feedback; nobody can read it through the app.
-- Read the answers in Supabase > Table Editor > feedback.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid default auth.uid(),
  role text check (char_length(role) <= 20),
  use text check (char_length(use) <= 20),
  name text check (char_length(name) <= 80),
  contact text check (char_length(contact) <= 120),
  city text check (char_length(city) <= 80),
  safe text check (char_length(safe) <= 1500),
  notes text check (char_length(notes) <= 1500)
);
alter table public.feedback enable row level security;
drop policy if exists "feedback: anyone sends" on public.feedback;
create policy "feedback: anyone sends" on public.feedback for insert to anon, authenticated with check (true);
