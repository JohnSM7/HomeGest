begin;
select * from no_plan();

create temp table ctx (k text primary key, v text);

select tests.create_user('11111111-1111-1111-1111-111111111111', 'a@test.dev');
select tests.create_user('22222222-2222-2222-2222-222222222222', 'b@test.dev');
select tests.create_user('33333333-3333-3333-3333-333333333333', 'c@test.dev');
select tests.create_user('44444444-4444-4444-4444-444444444444', 'd@test.dev');
select tests.create_user('55555555-5555-5555-5555-555555555555', 'e@test.dev');

insert into ctx select 'g', tests.q('11111111-1111-1111-1111-111111111111', $$select public.create_group('Piso', 'home')::text$$);

-- Token: solo en claro al crearlo
insert into ctx select 't1', tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'member', 1)$$, (select v from ctx where k = 'g')));
select is(length((select v from ctx where k = 't1')), 64, 'el token tiene 64 caracteres');
select is((select count(*)::int from public.invitations
            where token_hash = sha256(convert_to((select v from ctx where k = 't1'), 'UTF8'))),
  1, 'solo se guarda el hash del token');
select is((select count(*)::int from public.invitations
            where encode(token_hash, 'hex') = (select v from ctx where k = 't1')),
  0, 'el token en claro no está en la tabla');
select alike(tests.q('11111111-1111-1111-1111-111111111111', $$select token_hash::text from public.invitations limit 1$$),
  'ERR:42501:%', 'el cliente no puede leer token_hash');
select is(tests.q('11111111-1111-1111-1111-111111111111', $$select count(id) from public.invitations$$), '1',
  'el owner ve la lista de invitaciones (sin token)');

-- Vista previa antes de aceptar
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select space_name from public.preview_invitation(%L)$$, (select v from ctx where k = 't1'))),
  'Piso', 'la vista previa muestra el nombre del grupo');
select alike(tests.q('22222222-2222-2222-2222-222222222222', $$select space_name from public.preview_invitation('nope')$$),
  'ERR:22023:invalid_invitation', 'la vista previa de un token falso falla');

-- Uso único
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 't1'))),
  (select v from ctx where k = 'g'), 'B acepta la invitación');
select is((select uses from public.invitations limit 1), 1, 'la invitación cuenta un uso');
select alike(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 't1'))),
  'ERR:22023:invalid_invitation', 'una invitación de un solo uso no se reutiliza');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 't1'))),
  (select v from ctx where k = 'g'), 'el que ya es miembro puede reabrir el enlace (idempotente)');
select is((select uses from public.invitations limit 1), 1, 'y no consume otro uso');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select role::text from public.memberships where space_id = %L and user_id = auth.uid()$$,
         (select v from ctx where k = 'g'))), 'member', 'entra con el rol member');

-- Caducada
insert into ctx select 't2', tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'member', 5)$$, (select v from ctx where k = 'g')));
update public.invitations set expires_at = now() - interval '1 minute'
 where token_hash = sha256(convert_to((select v from ctx where k = 't2'), 'UTF8'));
select alike(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 't2'))),
  'ERR:22023:invalid_invitation', 'una invitación caducada no sirve');

-- Revocada
insert into ctx select 't3', tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'member', 5)$$, (select v from ctx where k = 'g')));
select is(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.revoke_invitation(i.id)::text from public.invitations i where i.revoked_at is null and i.uses = 0 and i.expires_at > now()$$)),
  '', 'el owner revoca una invitación');
select alike(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select public.accept_invitation(%L)::text$$, (select v from ctx where k = 't3'))),
  'ERR:22023:invalid_invitation', 'una invitación revocada no sirve');

-- Quién puede invitar y con qué rol
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.create_invitation(%L)$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un member no puede invitar');
select is(tests.q('22222222-2222-2222-2222-222222222222', $$select count(*) from public.invitations$$), '0',
  'un member no ve invitaciones');
select is(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.set_member_role(%L, '22222222-2222-2222-2222-222222222222', 'admin')::text$$,
         (select v from ctx where k = 'g'))), '', 'el owner asciende a B a admin');
select unalike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.create_invitation(%L, 'member')$$, (select v from ctx where k = 'g'))),
  'ERR%', 'un admin puede invitar como member');
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.create_invitation(%L, 'admin')$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un admin no puede invitar como admin');
select unalike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'admin')$$, (select v from ctx where k = 'g'))),
  'ERR%', 'el owner sí puede invitar como admin');
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'owner')$$, (select v from ctx where k = 'g'))),
  'ERR:22023:invalid_role', 'nadie se invita como owner');

-- Parámetros
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'member', 1, interval '31 days')$$, (select v from ctx where k = 'g'))),
  'ERR:22023:invalid_parameters', 'no más de 30 días');
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L, 'member', 0)$$, (select v from ctx where k = 'g'))),
  'ERR:22023:invalid_parameters', 'al menos un uso');

-- No se invita a un espacio personal
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  $$select public.create_invitation(s.id) from public.spaces s where s.type = 'personal'$$),
  'ERR:22023:invalid_space', 'los espacios personales no admiten invitaciones');

select * from finish();
rollback;
