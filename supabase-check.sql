-- Pull Up: check what is installed. Safe to run any time. It only reads.
select 'table' as kind, tablename as name from pg_tables where schemaname = 'public' and tablename in ('profiles','plans','plan_private')
union all
select 'bucket', id from storage.buckets where id in ('avatars','vlogs')
union all
select 'policy', tablename || ': ' || policyname from pg_policies where schemaname in ('public','storage')
order by 1, 2;
