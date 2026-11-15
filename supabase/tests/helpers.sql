-- Helpers de prueba. Las aserciones de pgTAP se ejecutan como superusuario;
-- las consultas "como usuario X" pasan por tests.q / tests.x, que cambian de rol
-- solo durante la consulta y devuelven el resultado o 'ERR:<sqlstate>:<mensaje>'.

create schema if not exists tests;

create or replace function tests.create_user(p_id uuid, p_email text) returns uuid
language plpgsql as $$
begin
  insert into auth.users (id, email) values (p_id, p_email);
  return p_id;
end $$;

-- Primera columna de la primera fila, como texto. p_uid null = anon.
create or replace function tests.q(p_uid uuid, p_sql text) returns text
language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  perform set_config('role', case when p_uid is null then 'anon' else 'authenticated' end, true);
  begin
    execute 'select t.x::text from (' || p_sql || ') as t(x) limit 1' into r;
  exception when others then
    r := 'ERR:' || sqlstate || ':' || sqlerrm;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  return coalesce(r, 'NULL');
end $$;

-- Sentencias DML: 'OK:<filas>' o 'ERR:<sqlstate>:<mensaje>'
create or replace function tests.x(p_uid uuid, p_sql text) returns text
language plpgsql as $$
declare n bigint; r text;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  perform set_config('role', case when p_uid is null then 'anon' else 'authenticated' end, true);
  begin
    execute p_sql;
    get diagnostics n = row_count;
    r := 'OK:' || n;
  exception when others then
    r := 'ERR:' || sqlstate || ':' || sqlerrm;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  return r;
end $$;
