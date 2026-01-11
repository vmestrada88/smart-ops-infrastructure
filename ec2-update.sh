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

# Actualizar submodules
echo "📦 Updating submodules..."
git submodule update --init --recursive
git submodule foreach 'git checkout production && git pull origin production'

# Restaurar backup de base de datos si existe
if [ -f ~/db_backup_*.sql ]; then
    echo "💾 Restoring database backup..."
    
    # Iniciar solo la base de datos
    docker compose -f docker-compose.prod.yml up -d db
    sleep 10
    
    # Encontrar el archivo de backup más reciente
    BACKUP_FILE=$(ls -t ~/db_backup_*.sql | head -1)
    echo "Using backup: $BACKUP_FILE"
    
    # Restaurar backup
    docker exec -i smart-ops-db psql -U postgres -d smartsolution_development < "$BACKUP_FILE"
    echo "✅ Database restored"
else
    echo "⚠️  No database backup found, skipping restore"
fi

# Reconstruir y levantar todos los servicios
echo "🔨 Building and starting services..."
docker compose -f docker-compose.prod.yml up -d --build

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
