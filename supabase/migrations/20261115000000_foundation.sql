-- Fase 0 · Fundamentos: identidad, grupos, membresías, invitaciones y auditoría.
-- Decisiones: ver docs/adr/ADR-001-stack.md y docs/adr/ADR-002-groups.md

create schema if not exists private;
revoke all on schema private from public;

create type public.space_type as enum ('personal', 'group');
create type public.group_kind as enum ('home', 'couple', 'family', 'trip', 'event', 'work', 'other');
create type public.member_role as enum ('owner', 'admin', 'member', 'limited');
create type public.member_status as enum ('active', 'left');

create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Perfiles (1:1 con auth.users) ------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  avatar_color text check (avatar_color is null or avatar_color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

-- Espacios: personal (1 miembro) o grupo ---------------------------------------
create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  type public.space_type not null,
  kind public.group_kind,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  modules text[] not null default '{}',
  currency char(3) not null default 'EUR',
  created_by uuid references public.profiles (id) on delete set null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint spaces_kind_matches_type check (
    (type = 'personal' and kind is null) or (type = 'group' and kind is not null)
  ),
  constraint spaces_modules_known check (
    modules <@ array['expenses', 'shopping', 'tasks', 'calendar', 'documents', 'assets']::text[]
  )
);
create trigger spaces_touch before update on public.spaces
  for each row execute function private.touch_updated_at();

-- Membresías -------------------------------------------------------------------
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.member_role not null default 'member',
  label text check (label is null or char_length(label) <= 40),
  status public.member_status not null default 'active',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  constraint memberships_left_consistent check ((status = 'left') = (left_at is not null))
);
create unique index memberships_one_active on public.memberships (space_id, user_id) where status = 'active';
create index memberships_user_active on public.memberships (user_id) where status = 'active';

-- Invitaciones: el token solo existe en claro al crearlo; se guarda su hash -----
create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  token_hash bytea not null unique,
  role public.member_role not null default 'member' check (role <> 'owner'),
  created_by uuid references public.profiles (id) on delete set null,
  expires_at timestamptz not null,
  max_uses integer not null default 1 check (max_uses between 1 and 20),
  uses integer not null default 0 check (uses >= 0),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint invitations_uses_le_max check (uses <= max_uses)
);
create index invitations_space on public.invitations (space_id);

-- Auditoría: solo se añade, nunca se edita ni se borra --------------------------
create table public.audit_log (
  id bigint generated always as identity primary key,
  space_id uuid,
  actor uuid,
  action text not null,
  entity_type text,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_log_space on public.audit_log (space_id, created_at desc);

create function private.audit_append_only() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'audit_log is append-only';
end $$;
create trigger audit_log_no_update_delete before update or delete on public.audit_log
  for each row execute function private.audit_append_only();
create trigger audit_log_no_truncate before truncate on public.audit_log
  for each statement execute function private.audit_append_only();

create function private.log(
  p_space uuid, p_action text, p_entity_type text, p_entity_id uuid, p_meta jsonb default '{}'::jsonb
) returns void
language sql security definer set search_path = '' as $$
  insert into public.audit_log (space_id, actor, action, entity_type, entity_id, meta)
  values (p_space, auth.uid(), p_action, p_entity_type, p_entity_id, coalesce(p_meta, '{}'::jsonb));
$$;
revoke all on function private.log(uuid, text, text, uuid, jsonb) from public;

-- Alta de usuario: perfil + espacio personal ------------------------------------
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_space uuid;
  v_name text := coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), split_part(coalesce(new.email, ''), '@', 1));
begin
  insert into public.profiles (id, display_name) values (new.id, left(v_name, 80));
  insert into public.spaces (type, name, modules, created_by)
  values ('personal', 'Personal', array['expenses', 'shopping', 'tasks', 'calendar'], new.id)
  returning id into v_space;
  insert into public.memberships (space_id, user_id, role) values (v_space, new.id, 'owner');
  return new;
end $$;
revoke all on function private.handle_new_user() from public;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Helpers de permisos (usados por las políticas RLS) -----------------------------
create function public.is_member(p_space uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.space_id = p_space and m.user_id = auth.uid() and m.status = 'active'
  );
$$;

create function public.has_role(p_space uuid, p_roles public.member_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.space_id = p_space and m.user_id = auth.uid() and m.status = 'active' and m.role = any (p_roles)
  );
$$;

create function public.shares_space_with(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.memberships a
    join public.memberships b on b.space_id = a.space_id
    where a.user_id = auth.uid() and a.status = 'active'
      and b.user_id = p_user and b.status = 'active'
  );
$$;

revoke all on function public.is_member(uuid) from public;
revoke all on function public.has_role(uuid, public.member_role[]) from public;
revoke all on function public.shares_space_with(uuid) from public;
grant execute on function public.is_member(uuid) to authenticated;
grant execute on function public.has_role(uuid, public.member_role[]) to authenticated;
grant execute on function public.shares_space_with(uuid) to authenticated;
