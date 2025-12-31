#!/bin/bash

# Script para actualizar Smart Ops en el servidor EC2

set -e

echo "========================================="
echo "Smart Ops - Script de Actualización"
echo "========================================="
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml no encontrado"
    echo "Asegúrate de estar en el directorio smart-ops-infrastructure"
    exit 1
fi

# Paso 1: Pull del código más reciente
echo "📥 Paso 1: Actualizando código desde Git..."
git pull origin main

# Paso 2: Detener servicios
echo ""
echo "🛑 Paso 2: Deteniendo servicios..."
docker compose down

# Paso 3: Crear base de datos si no existe
echo ""
echo "🗄️  Paso 3: Verificando base de datos..."
docker compose up -d db
sleep 5

# Verificar si la base de datos existe
DB_EXISTS=$(docker exec smart-ops-db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='smartsolution_production'" || echo "0")

if [ "$DB_EXISTS" = "1" ]; then
    echo "✅ Base de datos smartsolution_production ya existe"
else
    echo "📦 Creando base de datos smartsolution_production..."
    docker exec smart-ops-db psql -U postgres -c "CREATE DATABASE smartsolution_production;"
    echo "✅ Base de datos creada"
fi

# Paso 4: Rebuild de imágenes
echo ""
echo "🔨 Paso 4: Reconstruyendo imágenes..."
docker compose build --no-cache

# Paso 5: Levantar todos los servicios
echo ""
echo "🚀 Paso 5: Levantando servicios..."
docker compose up -d

# Paso 6: Verificar estado
echo ""
echo "⏳ Esperando que los servicios inicien..."
sleep 10

echo ""
echo "📊 Estado de los servicios:"
docker compose ps

# Paso 7: Probar endpoints
echo ""
echo "🧪 Probando endpoints..."
echo "Backend Health Check:"
curl -s http://localhost:5000/api/health && echo "" || echo "❌ Backend no responde"

echo ""
echo "========================================="
echo "✅ Actualización completada!"
echo "========================================="
echo ""
echo "📝 Comandos útiles:"
echo "  Ver logs:           docker compose logs -f"
echo "  Ver logs backend:   docker compose logs -f back-end"
echo "  Ver logs frontend:  docker compose logs -f front-end"
echo "  Reiniciar todo:     docker compose restart"
echo "  Ver estado:         docker compose ps"
