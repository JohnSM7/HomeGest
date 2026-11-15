begin;
select * from no_plan();

create temp table ctx (k text primary key, v text);

select tests.create_user('11111111-1111-1111-1111-111111111111', 'a@test.dev');
select tests.create_user('22222222-2222-2222-2222-222222222222', 'b@test.dev');
select tests.create_user('33333333-3333-3333-3333-333333333333', 'c@test.dev');

-- A crea el grupo g1; C crea el grupo g2; B no tiene grupos
insert into ctx select 'g1', tests.q('11111111-1111-1111-1111-111111111111', $$select public.create_group('Piso A', 'home')::text$$);
insert into ctx select 'g2', tests.q('33333333-3333-3333-3333-333333333333', $$select public.create_group('Viaje C', 'trip')::text$$);

select unalike((select v from ctx where k = 'g1'), 'ERR%', 'A crea su grupo');
select is((select role::text from public.memberships where space_id = (select v::uuid from ctx where k = 'g1')
            and user_id = '11111111-1111-1111-1111-111111111111'), 'owner', 'el creador es owner');
select is((select modules from public.spaces where id = (select v::uuid from ctx where k = 'g1')),
  array['expenses', 'shopping', 'tasks', 'calendar'], 'la plantilla home activa sus módulos');
select is((select modules from public.spaces where id = (select v::uuid from ctx where k = 'g2')),
  array['expenses', 'shopping'], 'la plantilla trip solo activa gastos y compra');

-- Aislamiento: B (sin grupos) no ve nada de g1 ni g2
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select count(*) from public.spaces where id = %L$$, (select v from ctx where k = 'g1'))), '0',
  'B no ve el espacio g1');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select count(*) from public.memberships where space_id = %L$$, (select v from ctx where k = 'g1'))), '0',
  'B no ve las membresías de g1');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select count(*) from public.audit_log where space_id = %L$$, (select v from ctx where k = 'g1'))), '0',
  'B no ve la auditoría de g1');
select is(tests.q('22222222-2222-2222-2222-222222222222', $$select count(*) from public.profiles$$), '1',
  'B solo ve su propio perfil');

-- A no ve el grupo de C
select is(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select count(*) from public.spaces where id = %L$$, (select v from ctx where k = 'g2'))), '0',
  'A no ve g2');
select is(tests.q('11111111-1111-1111-1111-111111111111', $$select count(*) from public.spaces$$), '2',
  'A ve exactamente su personal y g1');

-- Escrituras directas prohibidas (solo por RPC)
select alike(tests.x('22222222-2222-2222-2222-222222222222',
  $$insert into public.spaces (type, kind, name) values ('group', 'home', 'Intruso')$$), 'ERR:42501:%',
  'no se pueden insertar espacios directamente');
select alike(tests.x('22222222-2222-2222-2222-222222222222',
  format($$insert into public.memberships (space_id, user_id, role) values (%L, '22222222-2222-2222-2222-222222222222', 'owner')$$,
         (select v from ctx where k = 'g1'))), 'ERR:42501:%', 'B no puede añadirse como owner a g1');
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  format($$update public.memberships set role = 'member' where space_id = %L$$, (select v from ctx where k = 'g1'))),
  'ERR:42501:%', 'ni el owner puede editar membresías directamente');
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  format($$update public.spaces set name = 'Renombrado' where id = %L$$, (select v from ctx where k = 'g1'))),
  'ERR:42501:%', 'ni el owner puede editar spaces directamente');
select alike(tests.x('22222222-2222-2222-2222-222222222222',
  $$delete from public.spaces$$), 'ERR:42501:%', 'no se pueden borrar espacios directamente');

-- RPC: B no puede operar sobre g1
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.create_invitation(%L)$$, (select v from ctx where k = 'g1'))), 'ERR:42501:forbidden',
  'B no puede invitar a g1');
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.update_group(%L, 'Hack')::text$$, (select v from ctx where k = 'g1'))), 'ERR:42501:forbidden',
  'B no puede renombrar g1');
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.leave_group(%L)::text$$, (select v from ctx where k = 'g1'))), 'ERR:42501:not_a_member',
  'B no puede salir de un grupo que no es suyo');
select alike(tests.q('22222222-2222-2222-2222-222222222222', $$select public.accept_invitation('adivinando')::text$$),
  'ERR:22023:invalid_invitation', 'un token inventado no sirve');

-- Un miembro NO ve el espacio personal de otro (A y B comparten g1)
insert into ctx select 'tk', tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L)$$, (select v from ctx where k = 'g1')));
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 'tk'))),
  (select v from ctx where k = 'g1'), 'B se une a g1 con la invitación');

select is(tests.q('11111111-1111-1111-1111-111111111111',
  $$select count(*) from public.spaces where type = 'personal'$$), '1',
  'A (owner) ve solo su espacio personal, no el de B');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  $$select count(*) from public.spaces where type = 'personal'$$), '1',
  'B ve solo su espacio personal, no el de A');
select is(tests.q('11111111-1111-1111-1111-111111111111',
  $$select count(*) from public.memberships where user_id = '22222222-2222-2222-2222-222222222222'$$), '1',
  'A ve la membresía de B solo en el grupo compartido (no la personal)');

-- Perfiles: se ven los de quien comparte grupo, no los de extraños
select is(tests.q('11111111-1111-1111-1111-111111111111',
  $$select count(*) from public.profiles where id = '22222222-2222-2222-2222-222222222222'$$), '1',
  'A ve el perfil de B (comparten grupo)');
select is(tests.q('11111111-1111-1111-1111-111111111111',
  $$select count(*) from public.profiles where id = '33333333-3333-3333-3333-333333333333'$$), '0',
  'A no ve el perfil de C (extraño)');
select is(tests.x('22222222-2222-2222-2222-222222222222',
  $$update public.profiles set display_name = 'hackeado' where id = '11111111-1111-1111-1111-111111111111'$$),
  'OK:0', 'B no puede editar el perfil de A');

-- Pertenecer a varios grupos
insert into ctx select 'g3', tests.q('11111111-1111-1111-1111-111111111111', $$select public.create_group('Segundo', 'other')::text$$);
select is(tests.q('11111111-1111-1111-1111-111111111111', $$select count(*) from public.spaces where type = 'group'$$), '2',
  'A puede tener varios grupos');
select is(tests.q('22222222-2222-2222-2222-222222222222', $$select count(*) from public.spaces where type = 'group'$$), '1',
  'B sigue viendo solo g1');

select * from finish();
rollback;
