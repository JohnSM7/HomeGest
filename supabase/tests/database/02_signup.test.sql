begin;
select * from no_plan();

select tests.create_user('11111111-1111-1111-1111-111111111111', 'ana@test.dev');

select is((select count(*)::int from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  1, 'el alta crea el perfil');
select is((select display_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'ana', 'el nombre sale del email si no hay otro');
select is(
  (select count(*)::int from public.spaces s join public.memberships m on m.space_id = s.id
    where m.user_id = '11111111-1111-1111-1111-111111111111'
      and s.type = 'personal' and m.role = 'owner' and m.status = 'active'),
  1, 'existe exactamente un espacio personal con membresía owner');
select is(
  (select count(*)::int from public.memberships where user_id = '11111111-1111-1111-1111-111111111111'),
  1, 'y ninguna otra membresía');

-- El usuario ve su propio perfil y su espacio personal
select is(tests.q('11111111-1111-1111-1111-111111111111', $$select count(*) from public.spaces$$), '1',
  've su espacio personal');
select is(tests.q('11111111-1111-1111-1111-111111111111', $$select count(*) from public.profiles$$), '1',
  've su perfil');

-- Puede editar su nombre pero no otros campos
select is(tests.x('11111111-1111-1111-1111-111111111111',
  $$update public.profiles set display_name = 'Ana G'$$), 'OK:1', 'edita su nombre');
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  $$update public.profiles set id = gen_random_uuid()$$), 'ERR:42501:%', 'no puede cambiar su id');
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  $$update public.profiles set avatar_color = 'rojo'$$), 'ERR:23514:%', 'el color debe ser hexadecimal');

select * from finish();
rollback;
