begin;
select * from no_plan();

-- Cada tabla de public tiene RLS activa (equivale al chequeo de CI "sin RLS no se mergea")
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0, 'todas las tablas de public tienen RLS activada');

-- Toda función security definer fija search_path
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0, 'las funciones security definer fijan search_path');

-- anon no tiene privilegios sobre tablas de public
select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee = 'anon' and table_schema = 'public'),
  0, 'anon no tiene privilegios sobre tablas');

select tests.create_user('11111111-1111-1111-1111-111111111111', 'a@test.dev');

select alike(tests.q(null, $$select public.create_group('X')::text$$), 'ERR:42501:%',
  'anon no puede ejecutar create_group');
select alike(tests.q(null, $$select count(*) from public.spaces$$), 'ERR:42501:%',
  'anon no puede leer spaces');
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  $$select private.log(null, 'x', 'x', null, '{}'::jsonb)::text$$), 'ERR:42501:%',
  'un usuario no puede ejecutar funciones del esquema private');
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  $$select private.handle_new_user()::text$$), 'ERR:42501:%',
  'un usuario no puede invocar handle_new_user');

select * from finish();
rollback;
