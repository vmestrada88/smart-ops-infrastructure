#!/bin/bash

# Actualiza Smart Ops en el EC2 con las imágenes publicadas en GHCR.
# Se ejecuta EN EL SERVIDOR (lo llama deploy.sh / el workflow de GitHub Actions).
#
# Variables opcionales:
#   SERVICE    all | back-end | front-end   (por defecto: all)
#   IMAGE_TAG  etiqueta de la imagen a usar (por defecto: production)
#   GHCR_USER / GHCR_TOKEN  credenciales para descargar imágenes privadas
#   BACKUP_DIR carpeta de backups (por defecto: ~/backups)
#   KEEP_BACKUPS cuántos backups pre-deploy conservar (por defecto: 7)
#
# Este script NUNCA borra volúmenes ni restaura backups: la base de datos
# se mantiene intacta entre deploys.

set -euo pipefail

SERVICE="${SERVICE:-all}"
IMAGE_TAG="${IMAGE_TAG:-production}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
KEEP_BACKUPS="${KEEP_BACKUPS:-7}"
COMPOSE="docker compose -f docker-compose.prod.yml"
HEALTH_URL="http://localhost:5000/api/health"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

case "$SERVICE" in
  all) SERVICES="back-end front-end" ;;
  back-end|front-end) SERVICES="$SERVICE" ;;
  *) echo "❌ SERVICE inválido: $SERVICE (usa all, back-end o front-end)"; exit 1 ;;
esac

echo "======================================"
echo "Updating Smart Ops on EC2"
echo "  service:   $SERVICE"
echo "  image tag: $IMAGE_TAG"
echo "======================================"

if [ ! -f .env ]; then
  echo "❌ Missing .env file in $(pwd)"
  echo "Create it from .env.production.sample and set production secrets before deploy"
  exit 1
fi

# El workflow ya hizo checkout de production; si se corre a mano, actualizamos aquí.
if [ "${SKIP_GIT_PULL:-false}" != "true" ]; then
  echo "📥 Updating infrastructure repo (production)..."
  git fetch origin production
  git checkout production
  git reset --hard origin/production
fi

# 1. Backup de la base ANTES de tocar nada
if docker ps --format '{{.Names}}' | grep -qx smart-ops-db; then
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="$BACKUP_DIR/pre-deploy-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "💾 Backing up database to $BACKUP_FILE ..."
  docker exec smart-ops-db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$BACKUP_FILE"
  if [ ! -s "$BACKUP_FILE" ]; then
    echo "❌ Backup vacío; se cancela el deploy para no arriesgar datos"
    rm -f "$BACKUP_FILE"
    exit 1
  fi
  # Conservar solo los últimos $KEEP_BACKUPS
  ls -1t "$BACKUP_DIR"/pre-deploy-*.sql.gz 2>/dev/null | tail -n +"$((KEEP_BACKUPS + 1))" | xargs -r rm -f
else
  echo "⚠️  smart-ops-db no está corriendo; no se hace backup (primer arranque)"
fi

# 2. Login a GHCR
if [ -n "${GHCR_TOKEN:-}" ] && [ -n "${GHCR_USER:-}" ]; then
  echo "🔐 Logging in to GHCR..."
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
else
  echo "⚠️  GHCR credentials not set; attempting anonymous pulls"
fi

# 3. Guardar la imagen que corre ahora (para rollback)
declare -A PREVIOUS_IMAGE
for svc in $SERVICES; do
  cid="$($COMPOSE ps -q "$svc" 2>/dev/null || true)"
  if [ -n "$cid" ]; then
    PREVIOUS_IMAGE[$svc]="$(docker inspect --format '{{.Image}}' "$cid")"
  fi
done

# 4. Descargar imágenes nuevas y reiniciar SOLO los servicios de la app
export BACKEND_TAG="$IMAGE_TAG" FRONTEND_TAG="$IMAGE_TAG"
[ "$SERVICE" = "front-end" ] && export BACKEND_TAG=production
[ "$SERVICE" = "back-end" ] && export FRONTEND_TAG=production

echo "🔨 Pulling images: $SERVICES"
$COMPOSE pull $SERVICES
echo "🚀 Starting services..."
$COMPOSE up -d --no-build db
$COMPOSE up -d --no-build $SERVICES

# 5. Verificar salud del backend
healthy=false
for i in $(seq 1 12); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then healthy=true; break; fi
  echo "⏳ Waiting for API ($i/12)..."
  sleep 5
done

if [ "$healthy" != "true" ]; then
  echo "❌ Health check failed after deploy"
  if [ ${#PREVIOUS_IMAGE[@]} -gt 0 ]; then
    echo "↩️  Rolling back to the previous images..."
    for svc in "${!PREVIOUS_IMAGE[@]}"; do
      case "$svc" in
        back-end) repo=ghcr.io/vmestrada88/smart-ops-back-end; export BACKEND_TAG=rollback ;;
        front-end) repo=ghcr.io/vmestrada88/smart-ops-front-end; export FRONTEND_TAG=rollback ;;
      esac
      docker tag "${PREVIOUS_IMAGE[$svc]}" "$repo:rollback"
    done
    $COMPOSE up -d --no-build "${!PREVIOUS_IMAGE[@]}"
  fi
  $COMPOSE ps
  exit 1
fi

# 6. Limpiar solo imágenes sin uso (nunca volúmenes)
echo "🧹 Removing unused images..."
docker image prune -af >/dev/null 2>&1 || true
echo "   Disk: $(df -h / | tail -1 | awk '{print $5 " used, " $4 " free"}')"

echo "📊 Service status:"
$COMPOSE ps

echo ""
echo "======================================"
echo "✅ Update completed!"
echo "======================================"
