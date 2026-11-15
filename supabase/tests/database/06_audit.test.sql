begin;
select * from no_plan();

create temp table ctx (k text primary key, v text);

select tests.create_user('11111111-1111-1111-1111-111111111111', 'a@test.dev');
select tests.create_user('22222222-2222-2222-2222-222222222222', 'b@test.dev');
select tests.create_user('33333333-3333-3333-3333-333333333333', 'c@test.dev');

insert into ctx select 'g', tests.q('11111111-1111-1111-1111-111111111111', $$select public.create_group('Piso', 'home')::text$$);
insert into ctx select 't', tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L)$$, (select v from ctx where k = 'g')));
select tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 't')));
select tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.leave_group(%L)::text$$, (select v from ctx where k = 'g')));

-- Quedan registradas las acciones relevantes
select is((select count(*)::int from public.audit_log where action = 'group.created'), 1, 'auditoría: grupo creado');
select is((select count(*)::int from public.audit_log where action = 'invitation.created'), 1, 'auditoría: invitación creada');
select is((select count(*)::int from public.audit_log where action = 'member.joined'), 1, 'auditoría: alta de miembro');
select is((select count(*)::int from public.audit_log where action = 'member.left'), 1, 'auditoría: baja de miembro');
select is((select actor from public.audit_log where action = 'member.joined'),
  '22222222-2222-2222-2222-222222222222'::uuid, 'el actor es quien se une');
select is((select meta ->> 'role' from public.audit_log where action = 'member.joined'), 'member', 'con el rol en meta');
select is((select count(*)::int from public.audit_log where meta::text like '%' || (select v from ctx where k = 't') || '%'),
  0, 'el token nunca aparece en la auditoría');

-- Solo se añade: nadie puede editar ni borrar (ni siquiera el superusuario)
select throws_ok($$update public.audit_log set action = 'x'$$, 'P0001', 'audit_log is append-only', 'no se puede editar');
select throws_ok($$delete from public.audit_log$$, 'P0001', 'audit_log is append-only', 'no se puede borrar');
select throws_ok($$truncate public.audit_log$$, 'P0001', 'audit_log is append-only', 'no se puede vaciar');

-- Y los usuarios no pueden escribir directamente
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  $$insert into public.audit_log (action) values ('falso')$$), 'ERR:42501:%', 'insertar en la auditoría está prohibido');
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  $$update public.audit_log set action = 'x'$$), 'ERR:42501:%', 'editarla está prohibido');
select alike(tests.x('11111111-1111-1111-1111-111111111111',
  $$delete from public.audit_log$$), 'ERR:42501:%', 'borrarla está prohibido');

-- Visibilidad: los owner/admin del grupo la ven; un exmiembro y un extraño no
select cmp_ok(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select count(*) from public.audit_log where space_id = %L$$, (select v from ctx where k = 'g')))::int,
  '>=', 4, 'el owner ve la auditoría de su grupo');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select count(*) from public.audit_log where space_id = %L$$, (select v from ctx where k = 'g'))), '0',
  'un exmiembro no ve la auditoría');
select is(tests.q('33333333-3333-3333-3333-333333333333', $$select count(*) from public.audit_log$$), '0',
  'un extraño no ve ninguna auditoría');

select * from finish();
rollback;
