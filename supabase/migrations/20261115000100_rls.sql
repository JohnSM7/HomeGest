-- Fase 0 · Row Level Security y privilegios.
-- Principio: denegar por defecto. Las escrituras de grupos, membresías e invitaciones
-- pasan SOLO por las funciones RPC (security definer) de la siguiente migración.

alter table public.profiles enable row level security;
alter table public.spaces enable row level security;
alter table public.memberships enable row level security;
alter table public.invitations enable row level security;
alter table public.audit_log enable row level security;

-- Supabase concede ALL a anon/authenticated por defecto en el esquema public: se retira.
revoke all on public.profiles, public.spaces, public.memberships, public.invitations, public.audit_log
  from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_color) on public.profiles to authenticated;
grant select on public.spaces to authenticated;
grant select on public.memberships to authenticated;
-- token_hash no es legible desde el cliente
grant select (id, space_id, role, created_by, expires_at, max_uses, uses, revoked_at, created_at)
  on public.invitations to authenticated;
grant select on public.audit_log to authenticated;

grant all on public.profiles, public.spaces, public.memberships, public.invitations, public.audit_log
  to service_role;

create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_space_with(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy spaces_select on public.spaces for select to authenticated
  using (public.is_member(id));

create policy memberships_select on public.memberships for select to authenticated
  using (public.is_member(space_id));

create policy invitations_select on public.invitations for select to authenticated
  using (public.has_role(space_id, array['owner', 'admin']::public.member_role[]));

create policy audit_select on public.audit_log for select to authenticated
  using (
    (space_id is not null and public.has_role(space_id, array['owner', 'admin']::public.member_role[]))
    or (space_id is null and actor = auth.uid())
  );
