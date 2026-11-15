begin;
select * from no_plan();

create temp table ctx (k text primary key, v text);

select tests.create_user('11111111-1111-1111-1111-111111111111', 'a@test.dev');
select tests.create_user('22222222-2222-2222-2222-222222222222', 'b@test.dev');
select tests.create_user('33333333-3333-3333-3333-333333333333', 'c@test.dev');

insert into ctx select 'g', tests.q('11111111-1111-1111-1111-111111111111', $$select public.create_group('Piso', 'home')::text$$);

create or replace function pg_temp.join_as(p_user uuid, p_role text default 'member') returns text language plpgsql as $$
declare t text;
begin
  t := tests.q('11111111-1111-1111-1111-111111111111',
    format($q$select public.create_invitation(%L, %L, 1)$q$, (select v from ctx where k = 'g'), p_role));
  return tests.q(p_user, format($q$select public.accept_invitation(%L)::text$q$, t));
end $$;

select is(pg_temp.join_as('22222222-2222-2222-2222-222222222222'), (select v from ctx where k = 'g'), 'B entra');
select is(pg_temp.join_as('33333333-3333-3333-3333-333333333333'), (select v from ctx where k = 'g'), 'C entra');

-- Salir revoca el acceso al instante
select is(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select count(*) from public.spaces where id = %L$$, (select v from ctx where k = 'g'))), '1', 'C ve el grupo');
select is(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select public.leave_group(%L)::text$$, (select v from ctx where k = 'g'))), '', 'C sale del grupo');
select is(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select count(*) from public.spaces where id = %L$$, (select v from ctx where k = 'g'))), '0',
  'C deja de ver el grupo inmediatamente');
select is(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select count(*) from public.memberships where space_id = %L$$, (select v from ctx where k = 'g'))), '0',
  'C deja de ver las membresías');
select is((select status::text from public.memberships where user_id = '33333333-3333-3333-3333-333333333333'
            and space_id = (select v::uuid from ctx where k = 'g')), 'left', 'queda constancia de que salió');

-- Puede volver con una invitación nueva (historial conservado)
select is(pg_temp.join_as('33333333-3333-3333-3333-333333333333'), (select v from ctx where k = 'g'), 'C vuelve a entrar');
select is((select count(*)::int from public.memberships where user_id = '33333333-3333-3333-3333-333333333333'
            and space_id = (select v::uuid from ctx where k = 'g')), 2, 'con dos filas: la antigua y la nueva');

-- El espacio personal no se abandona
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  $$select public.leave_group(s.id)::text from public.spaces s where s.type = 'personal'$$),
  'ERR:22023:invalid_space', 'no se puede abandonar el espacio personal');

-- Último owner
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.leave_group(%L)::text$$, (select v from ctx where k = 'g'))),
  'ERR:P0001:last_owner', 'el último owner no puede salir mientras haya más gente');
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.set_member_role(%L, '11111111-1111-1111-1111-111111111111', 'member')::text$$, (select v from ctx where k = 'g'))),
  'ERR:P0001:last_owner', 'ni degradarse a sí mismo');

-- Roles: solo owner cambia roles
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.set_member_role(%L, '33333333-3333-3333-3333-333333333333', 'admin')::text$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un member no cambia roles');
select is(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.set_member_role(%L, '22222222-2222-2222-2222-222222222222', 'admin')::text$$, (select v from ctx where k = 'g'))),
  '', 'el owner hace admin a B');
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.set_member_role(%L, '33333333-3333-3333-3333-333333333333', 'admin')::text$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un admin tampoco cambia roles');

-- Expulsar
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.remove_member(%L, '11111111-1111-1111-1111-111111111111')::text$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un admin no puede expulsar al owner');
select alike(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.remove_member(%L, '22222222-2222-2222-2222-222222222222')::text$$, (select v from ctx where k = 'g'))),
  'ERR:22023:use_leave', 'para irse hay que usar leave_group');
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.remove_member(%L, '33333333-3333-3333-3333-333333333333')::text$$, (select v from ctx where k = 'g'))),
  '', 'un admin expulsa a un member');
select is(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select count(*) from public.spaces where id = %L$$, (select v from ctx where k = 'g'))), '0',
  'el expulsado pierde el acceso al instante');
select alike(tests.q('33333333-3333-3333-3333-333333333333',
  format($$select public.remove_member(%L, '22222222-2222-2222-2222-222222222222')::text$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un exmiembro no puede operar');

-- Traspaso de propiedad y salida del owner original
select is(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.set_member_role(%L, '22222222-2222-2222-2222-222222222222', 'owner')::text$$, (select v from ctx where k = 'g'))),
  '', 'se traspasa la propiedad a B');
select is(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.leave_group(%L)::text$$, (select v from ctx where k = 'g'))), '', 'ahora A puede salir');

-- Salir siendo el único miembro archiva el grupo
select is(tests.q('22222222-2222-2222-2222-222222222222',
  format($$select public.leave_group(%L)::text$$, (select v from ctx where k = 'g'))), '', 'B sale siendo el último');
select isnt((select archived_at from public.spaces where id = (select v::uuid from ctx where k = 'g')), null,
  'el grupo vacío queda archivado');
select alike(tests.q('11111111-1111-1111-1111-111111111111',
  format($$select public.create_invitation(%L)$$, (select v from ctx where k = 'g'))),
  'ERR:42501:forbidden', 'un grupo archivado no admite invitaciones');

-- Límite de grupos por usuario
create or replace function pg_temp.make_groups(n int) returns void language plpgsql as $$
begin
  for i in 1..n loop
    perform tests.q('33333333-3333-3333-3333-333333333333', format($q$select public.create_group('G%s')::text$q$, i));
  end loop;
end $$;
select pg_temp.make_groups(20);
select alike(tests.q('33333333-3333-3333-3333-333333333333', $$select public.create_group('G21')::text$$),
  'ERR:54000:too_many_groups', 'máximo 20 grupos activos por usuario');

-- update_group
select tests.create_user('66666666-6666-6666-6666-666666666666', 'f@test.dev');
insert into ctx select 'g2', tests.q('66666666-6666-6666-6666-666666666666', $$select public.create_group('Viaje', 'trip')::text$$);
select is(tests.q('66666666-6666-6666-6666-666666666666',
  format($$select public.update_group(%L, 'Viaje Roma', array['expenses'])::text$$, (select v from ctx where k = 'g2'))),
  '', 'el owner renombra y cambia módulos');
select is((select name from public.spaces where id = (select v::uuid from ctx where k = 'g2')), 'Viaje Roma', 'nombre actualizado');
select alike(tests.q('66666666-6666-6666-6666-666666666666',
  format($$select public.update_group(%L, null, array['inventado'])::text$$, (select v from ctx where k = 'g2'))),
  'ERR:23514:%', 'no admite módulos desconocidos');

select * from finish();
rollback;
