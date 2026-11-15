-- Fase 0 · Funciones RPC: crear grupo, invitar, unirse, salir, roles.
-- Todas son security definer con search_path vacío y comprueban auth.uid() ellas mismas.

create function public.default_modules(p_kind public.group_kind) returns text[]
language sql immutable set search_path = '' as $$
  select case p_kind
    when 'trip' then array['expenses', 'shopping']
    when 'event' then array['expenses', 'tasks']
    when 'work' then array['expenses', 'tasks']
    when 'other' then array['expenses', 'shopping', 'tasks']
    else array['expenses', 'shopping', 'tasks', 'calendar']
  end;
$$;

create function public.create_group(p_name text, p_kind public.group_kind default 'other')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  select count(*) into v_count
  from public.memberships m join public.spaces s on s.id = m.space_id
  where m.user_id = v_uid and m.status = 'active' and s.type = 'group' and s.archived_at is null;
  if v_count >= 20 then raise exception 'too_many_groups' using errcode = '54000'; end if;

  insert into public.spaces (type, kind, name, modules, created_by)
  values ('group', p_kind, btrim(p_name), public.default_modules(p_kind), v_uid)
  returning id into v_id;
  insert into public.memberships (space_id, user_id, role) values (v_id, v_uid, 'owner');
  perform private.log(v_id, 'group.created', 'space', v_id, jsonb_build_object('kind', p_kind));
  return v_id;
end $$;

create function public.update_group(p_space uuid, p_name text default null, p_modules text[] default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not public.has_role(p_space, array['owner', 'admin']::public.member_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_name is not null and char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  update public.spaces
     set name = coalesce(btrim(p_name), name), modules = coalesce(p_modules, modules)
   where id = p_space and type = 'group' and archived_at is null;
  if not found then raise exception 'invalid_space' using errcode = '22023'; end if;
  perform private.log(p_space, 'group.updated', 'space', p_space, '{}'::jsonb);
end $$;

create function public.create_invitation(
  p_space uuid,
  p_role public.member_role default 'member',
  p_max_uses integer default 1,
  p_ttl interval default interval '7 days'
) returns text language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
  v_active integer;
  v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not public.has_role(p_space, array['owner', 'admin']::public.member_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not exists (select 1 from public.spaces where id = p_space and type = 'group' and archived_at is null) then
    raise exception 'invalid_space' using errcode = '22023';
  end if;
  if p_role = 'owner' then raise exception 'invalid_role' using errcode = '22023'; end if;
  if p_role = 'admin' and not public.has_role(p_space, array['owner']::public.member_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_max_uses not between 1 and 20 or p_ttl <= interval '0' or p_ttl > interval '30 days' then
    raise exception 'invalid_parameters' using errcode = '22023';
  end if;
  select count(*) into v_active from public.invitations
   where space_id = p_space and revoked_at is null and expires_at > now() and uses < max_uses;
  if v_active >= 20 then raise exception 'too_many_invitations' using errcode = '54000'; end if;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into public.invitations (space_id, token_hash, role, created_by, expires_at, max_uses)
  values (p_space, sha256(convert_to(v_token, 'UTF8')), p_role, v_uid, now() + p_ttl, p_max_uses)
  returning id into v_id;
  perform private.log(p_space, 'invitation.created', 'invitation', v_id,
                      jsonb_build_object('role', p_role, 'max_uses', p_max_uses));
  return v_token;
end $$;

create function public.revoke_invitation(p_invitation uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_space uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select space_id into v_space from public.invitations where id = p_invitation;
  if v_space is null or not public.has_role(v_space, array['owner', 'admin']::public.member_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.invitations set revoked_at = now() where id = p_invitation and revoked_at is null;
  perform private.log(v_space, 'invitation.revoked', 'invitation', p_invitation, '{}'::jsonb);
end $$;

create function public.preview_invitation(p_token text)
returns table (space_name text, kind public.group_kind, inviter_name text, member_count integer, role public.member_role)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  return query
  select s.name, s.kind, p.display_name,
         (select count(*)::integer from public.memberships m where m.space_id = s.id and m.status = 'active'),
         i.role
  from public.invitations i
  join public.spaces s on s.id = i.space_id
  left join public.profiles p on p.id = i.created_by
  where i.token_hash = sha256(convert_to(coalesce(p_token, ''), 'UTF8'))
    and i.revoked_at is null and i.expires_at > now() and i.uses < i.max_uses
    and s.archived_at is null;
  if not found then raise exception 'invalid_invitation' using errcode = '22023'; end if;
end $$;

create function public.accept_invitation(p_token text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_inv public.invitations%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select i.* into v_inv from public.invitations i
   where i.token_hash = sha256(convert_to(coalesce(p_token, ''), 'UTF8'))
   for update;
  if not found or v_inv.revoked_at is not null or v_inv.expires_at <= now()
     or not exists (select 1 from public.spaces s where s.id = v_inv.space_id and s.archived_at is null) then
    raise exception 'invalid_invitation' using errcode = '22023';
  end if;
  -- Ya es miembro: idempotente, no consume la invitación
  if public.is_member(v_inv.space_id) then return v_inv.space_id; end if;
  if v_inv.uses >= v_inv.max_uses then raise exception 'invalid_invitation' using errcode = '22023'; end if;

  insert into public.memberships (space_id, user_id, role) values (v_inv.space_id, v_uid, v_inv.role);
  update public.invitations set uses = uses + 1 where id = v_inv.id;
  perform private.log(v_inv.space_id, 'member.joined', 'membership', null,
                      jsonb_build_object('user', v_uid, 'role', v_inv.role, 'invitation', v_inv.id));
  return v_inv.space_id;
end $$;

create function public.leave_group(p_space uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_role public.member_role;
  v_other_owners integer;
  v_others integer;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.spaces where id = p_space and type = 'group') then
    raise exception 'invalid_space' using errcode = '22023';
  end if;
  select m.role into v_role from public.memberships m
   where m.space_id = p_space and m.user_id = v_uid and m.status = 'active' for update;
  if not found then raise exception 'not_a_member' using errcode = '42501'; end if;

  select count(*) filter (where role = 'owner' and user_id <> v_uid), count(*) filter (where user_id <> v_uid)
    into v_other_owners, v_others
  from public.memberships where space_id = p_space and status = 'active';
  if v_role = 'owner' and v_other_owners = 0 and v_others > 0 then
    raise exception 'last_owner' using errcode = 'P0001';
  end if;

  update public.memberships set status = 'left', left_at = now()
   where space_id = p_space and user_id = v_uid and status = 'active';
  perform private.log(p_space, 'member.left', 'membership', null, jsonb_build_object('user', v_uid));
  if v_others = 0 then
    update public.spaces set archived_at = now() where id = p_space;
    perform private.log(p_space, 'group.archived', 'space', p_space, '{}'::jsonb);
  end if;
end $$;

create function public.set_member_role(p_space uuid, p_user uuid, p_role public.member_role)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_old public.member_role;
  v_other_owners integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not public.has_role(p_space, array['owner']::public.member_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not exists (select 1 from public.spaces where id = p_space and type = 'group' and archived_at is null) then
    raise exception 'invalid_space' using errcode = '22023';
  end if;
  select m.role into v_old from public.memberships m
   where m.space_id = p_space and m.user_id = p_user and m.status = 'active' for update;
  if not found then raise exception 'not_a_member' using errcode = '22023'; end if;
  if v_old = 'owner' and p_role <> 'owner' then
    select count(*) into v_other_owners from public.memberships
     where space_id = p_space and status = 'active' and role = 'owner' and user_id <> p_user;
    if v_other_owners = 0 then raise exception 'last_owner' using errcode = 'P0001'; end if;
  end if;
  update public.memberships set role = p_role
   where space_id = p_space and user_id = p_user and status = 'active';
  perform private.log(p_space, 'member.role_changed', 'membership', null,
                      jsonb_build_object('user', p_user, 'from', v_old, 'to', p_role));
end $$;

create function public.remove_member(p_space uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_caller public.member_role;
  v_target public.member_role;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if p_user = v_uid then raise exception 'use_leave' using errcode = '22023'; end if;
  select m.role into v_caller from public.memberships m
   where m.space_id = p_space and m.user_id = v_uid and m.status = 'active';
  if v_caller is null or v_caller not in ('owner', 'admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select m.role into v_target from public.memberships m
   where m.space_id = p_space and m.user_id = p_user and m.status = 'active' for update;
  if not found then raise exception 'not_a_member' using errcode = '22023'; end if;
  if v_caller = 'admin' and v_target in ('owner', 'admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.memberships set status = 'left', left_at = now()
   where space_id = p_space and user_id = p_user and status = 'active';
  perform private.log(p_space, 'member.removed', 'membership', null, jsonb_build_object('user', p_user));
end $$;

-- Ejecución: solo usuarios autenticados (PUBLIC y anon fuera)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('default_modules', 'create_group', 'update_group', 'create_invitation',
                        'revoke_invitation', 'preview_invitation', 'accept_invitation',
                        'leave_group', 'set_member_role', 'remove_member')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
