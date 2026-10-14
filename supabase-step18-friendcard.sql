-- Pull Up: step 18 (add a friend from a shared profile link). Safe to run more than once.
-- Returns only a first name and role so you can follow someone you meet in person.
create or replace function public.friend_card(uid uuid)
returns table (first_name text, role text)
language sql security definer set search_path = public as $$
  select p.first_name, p.role from public.profiles p where p.id = uid
$$;
revoke all on function public.friend_card(uuid) from public, anon;
grant execute on function public.friend_card(uuid) to authenticated;
