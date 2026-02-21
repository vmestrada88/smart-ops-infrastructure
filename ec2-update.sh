#!/bin/bash

# Script para actualizar la aplicación en EC2 desde production
# Ejecutar este script EN EL SERVIDOR EC2

set -e

echo "======================================"
echo "Updating Smart Ops on EC2"
echo "======================================"

# Detener contenedores actuales
echo "🛑 Stopping current containers..."
cd ~/smart-ops-infrastructure
docker compose -f docker-compose.prod.yml down || true

# Actualizar código desde GitHub (branch production)
echo "📥 Pulling latest code from production branch..."
git checkout production
git pull origin production

# Verificar variables de entorno de producción
if [ ! -f .env ]; then
  echo "❌ Missing .env file in $(pwd)"
  echo "Create it from .env.example and set production secrets before deploy"
  exit 1
fi

# Actualizar submodules
echo "📦 Updating submodules..."
git submodule update --init --recursive
git submodule foreach 'git checkout production && git pull origin production'

# Restaurar backup de base de datos si existe
if ls ~/db_backup_*.sql >/dev/null 2>&1; then
    echo "💾 Restoring database backup..."
    
    # Iniciar solo la base de datos
    docker compose -f docker-compose.prod.yml up -d db
    sleep 10
    
    # Encontrar el archivo de backup más reciente
    BACKUP_FILE=$(ls -t ~/db_backup_*.sql | head -1)
    echo "Using backup: $BACKUP_FILE"
    
    # Restaurar backup
    docker exec -i smart-ops-db psql -U postgres -d smartsolution_production < "$BACKUP_FILE"
    echo "✅ Database restored"
else
    echo "⚠️  No database backup found, skipping restore"
fi

# Login to GHCR if credentials provided (GHCR_TOKEN and GHCR_USER)
if [ -n "$GHCR_TOKEN" ] && [ -n "$GHCR_USER" ]; then
  echo "🔐 Logging in to GHCR..."
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
else
  echo "⚠️  GHCR credentials not set; attempting anonymous pulls (may fail for private images)"
fi

# Pull images and start services
echo "🔨 Pulling images and starting services..."
docker compose -f docker-compose.prod.yml pull || true
# Use no-build to ensure we don't try to build on the server
docker compose -f docker-compose.prod.yml up -d --no-build

# Esperar a que los servicios estén listos
echo "⏳ Waiting for services to be ready..."
sleep 15

# Verificar estado
echo "📊 Service status:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "======================================"
echo "✅ Update completed!"
echo "======================================"
echo ""
echo "Services should be available at:"
echo "  Frontend: http://$(curl -s ifconfig.me)"
echo "  Backend API: http://$(curl -s ifconfig.me):5000"
echo ""
echo "Check logs with:"
echo "  docker compose -f docker-compose.prod.yml logs -f"
