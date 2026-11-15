#!/usr/bin/env bash
# Ejecuta migraciones + tests pgTAP en un PostgreSQL 16 desechable (sin Docker ni Supabase).
# Uso: supabase/tests/run-local.sh            (necesita postgresql-16 y postgresql-16-pgtap)
# Variables: PGTEST_DIR (datos del clúster), PGTEST_PORT
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
DIR="${PGTEST_DIR:-/var/tmp/homegest-pgtest}"
PORT="${PGTEST_PORT:-54329}"
DB=homegest_test

run_pg() { if [ "$(id -u)" = 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi; }

if [ ! -d "$DIR/data" ]; then
  mkdir -p "$DIR"
  [ "$(id -u)" = 0 ] && chown postgres:postgres "$DIR"
  run_pg "$PGBIN/initdb" -D "$DIR/data" --auth=trust -U postgres >/dev/null
fi
if ! run_pg "$PGBIN/pg_ctl" -D "$DIR/data" status >/dev/null 2>&1; then
  run_pg "$PGBIN/pg_ctl" -D "$DIR/data" -o "-p $PORT -k $DIR -c listen_addresses=''" -l "$DIR/pg.log" -w start >/dev/null
fi

PSQL=(run_pg "$PGBIN/psql" -h "$DIR" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -d postgres -c "drop database if exists $DB" -c "create database $DB"
"${PSQL[@]}" -d "$DB" -c "create extension pgtap"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/shim/auth_shim.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "migración: $(basename "$f")"
  "${PSQL[@]}" -d "$DB" -f "$f"
done
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/helpers.sql"

run_pg pg_prove -h "$DIR" -p "$PORT" -U postgres -d "$DB" "$ROOT"/supabase/tests/database/*.test.sql
