#!/bin/sh
# One-off: back up the production DB, then apply the idempotent backend
# migrations that were never run in production (Clients.status, Jobs schedule
# columns, Users.color). Runs ON the EC2 host.
set -eu

envof() { docker exec smart-ops-backend printenv "$1" 2>/dev/null || true; }
DB_HOST=$(envof DB_HOST); DB_PORT=$(envof DB_PORT); DB_NAME=$(envof DB_NAME)
DB_USER=$(envof DB_USER); DB_SSL=$(envof DB_SSL)

echo "== /api/clients before:"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:5000/api/clients || true

case "$DB_HOST" in
  db|smart-ops-db|localhost|127.0.0.1|"")
    echo "DB: local container"
    PSQL="docker exec -i smart-ops-db psql -v ON_ERROR_STOP=1 -U $DB_USER -d $DB_NAME"
    DUMP="docker exec smart-ops-db pg_dump -U $DB_USER -d $DB_NAME" ;;
  *)
    echo "DB: external host"
    SSLMODE=disable; [ "$DB_SSL" = "true" ] && SSLMODE=require
    PSQL="docker exec -i -e PGSSLMODE=$SSLMODE smart-ops-backend sh -c 'PGPASSWORD=\"\$DB_PASSWORD\" psql -v ON_ERROR_STOP=1 -h \"\$DB_HOST\" -p \"\${DB_PORT:-5432}\" -U \"\$DB_USER\" -d \"\$DB_NAME\"'"
    DUMP="docker exec -e PGSSLMODE=$SSLMODE smart-ops-backend sh -c 'PGPASSWORD=\"\$DB_PASSWORD\" pg_dump -h \"\$DB_HOST\" -p \"\${DB_PORT:-5432}\" -U \"\$DB_USER\" -d \"\$DB_NAME\"'" ;;
esac

echo "== Columns before:"
echo "SELECT table_name, column_name FROM information_schema.columns WHERE table_name IN ('Clients','Jobs','Users') ORDER BY 1,2;" | eval "$PSQL"

TS=$(date +%Y%m%d_%H%M%S)
BK=~/premigration_backup_$TS.sql
echo "== Backup -> $BK"
eval "$DUMP" > "$BK"
SZ=$(wc -c < "$BK")
echo "backup size: $SZ bytes"
[ "$SZ" -gt 1000 ] || { echo "Backup looks empty, aborting"; exit 1; }

echo "== Applying migrations"
echo "-- 20260302_add_client_status_column.sql"
{ echo "BEGIN;"; cat <<'SQL'
ALTER TABLE "Clients"
ADD COLUMN IF NOT EXISTS "status" VARCHAR(20) NOT NULL DEFAULT 'active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'clients_status_check'
  ) THEN
    ALTER TABLE "Clients"
    ADD CONSTRAINT clients_status_check
    CHECK ("status" IN ('prospect', 'active', 'inactive'));
  END IF;
END $$;
SQL
echo "COMMIT;"; } | eval "$PSQL"
echo "-- 20260223_add_jobs_schedule_columns.sql"
{ echo "BEGIN;"; cat <<'SQL'
-- Ensure legacy Jobs table includes scheduling columns expected by current backend
-- Safe to run multiple times
ALTER TABLE public."Jobs" ADD COLUMN IF NOT EXISTS "startTime" TIMESTAMPTZ;
ALTER TABLE public."Jobs" ADD COLUMN IF NOT EXISTS "endTime" TIMESTAMPTZ;
ALTER TABLE public."Jobs" ADD COLUMN IF NOT EXISTS "assignedTo" INTEGER[];
ALTER TABLE public."Jobs" ADD COLUMN IF NOT EXISTS "status" VARCHAR(32) DEFAULT 'scheduled';

UPDATE public."Jobs"
SET "startTime" = COALESCE("startTime", date),
    "endTime" = COALESCE("endTime", date),
    "status" = COALESCE("status", 'scheduled');

SQL
echo "COMMIT;"; } | eval "$PSQL" || echo "WARNING: 20260223_add_jobs_schedule_columns.sql failed (rolled back)"
echo "-- 20260223_add_user_color_column.sql"
{ echo "BEGIN;"; cat <<'SQL'
-- Ensure User color column exists (legacy DB dumps may miss it)
-- Safe to run multiple times
DO $$
BEGIN
  IF to_regclass('public."Users"') IS NOT NULL THEN
    ALTER TABLE public."Users" ADD COLUMN IF NOT EXISTS color VARCHAR(50);
  END IF;

  IF to_regclass('public.users') IS NOT NULL THEN
    ALTER TABLE public.users ADD COLUMN IF NOT EXISTS color VARCHAR(50);
  END IF;
END $$;

SQL
echo "COMMIT;"; } | eval "$PSQL" || echo "WARNING: 20260223_add_user_color_column.sql failed (rolled back)"

echo "== Columns after:"
echo "SELECT table_name, column_name FROM information_schema.columns WHERE table_name IN ('Clients','Jobs','Users') ORDER BY 1,2;" | eval "$PSQL"

echo "== /api/clients after:"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:5000/api/clients || true
# Workflow logs are public (public repo): print only error lines about columns, never data or URLs
echo "== backend column errors (last 200 log lines)"
docker logs --tail 200 smart-ops-backend 2>&1 | grep -i "column .* does not exist" | tail -5 || true
