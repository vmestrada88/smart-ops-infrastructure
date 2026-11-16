#!/bin/sh
# One-off: back up the production DB, then add the missing Invoices."taxExempt"
# column (backend migrations/20261116_add_invoice_tax_exempt_column.sql). Runs ON the EC2 host.
set -eu

envof() { docker exec smart-ops-backend printenv "$1" 2>/dev/null || true; }
DB_HOST=$(envof DB_HOST); DB_NAME=$(envof DB_NAME); DB_USER=$(envof DB_USER); DB_SSL=$(envof DB_SSL)

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

COLS="SELECT table_name, column_name FROM information_schema.columns WHERE table_name IN ('Invoices','InvoiceItems') ORDER BY 1,2;"
echo "== Columns before:"; echo "$COLS" | eval "$PSQL"

echo "== backend invoice column errors before (last 500 log lines)"
docker logs --tail 500 smart-ops-backend 2>&1 | grep -i "column .* does not exist" | sort | uniq -c | tail -10 || true

TS=$(date +%Y%m%d_%H%M%S); BK=~/premigration_backup_$TS.sql
echo "== Backup -> $BK"
eval "$DUMP" > "$BK"
SZ=$(wc -c < "$BK"); echo "backup size: $SZ bytes"
[ "$SZ" -gt 1000 ] || { echo "Backup looks empty, aborting"; exit 1; }

echo "== Applying 20261116_add_invoice_tax_exempt_column.sql"
{ echo "BEGIN;"; cat <<'SQL'
ALTER TABLE public."Invoices" ADD COLUMN IF NOT EXISTS "taxExempt" BOOLEAN DEFAULT false;
UPDATE public."Invoices" SET "taxExempt" = false WHERE "taxExempt" IS NULL;
SQL
echo "COMMIT;"; } | eval "$PSQL"

echo "== Columns after:"; echo "$COLS" | eval "$PSQL"
# Public repo logs: print only status codes / schema names, never data
echo "== /api/invoices without token (expect 401):"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:5000/api/invoices || true
