#!/bin/bash

# Script de despliegue automatizado para AWS EC2
# Uso: ./deploy.sh [EC2_IP] [KEY_PATH]

set -e

EC2_IP=$1
KEY_PATH=${2:-"../aws-keys/smart-ops-docker-key.pem"}

if [ -z "$EC2_IP" ]; then
    echo "❌ Error: Debes proporcionar la IP de EC2"
    echo "Uso: ./deploy.sh <EC2_IP> [KEY_PATH]"
    exit 1
fi

echo "🚀 Iniciando despliegue en EC2: $EC2_IP"
echo "================================================"

# 1. Verificar conexión SSH
echo "📡 Verificando conexión SSH..."
ssh -i "$KEY_PATH" -o ConnectTimeout=5 ubuntu@$EC2_IP "echo '✅ Conexión exitosa'"

# 2. Instalar Docker si no existe
echo "🐳 Verificando Docker..."
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << 'EOF'
if ! command -v docker &> /dev/null; then
    echo "📦 Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker ubuntu
    sudo apt install docker-compose-plugin -y
    echo "✅ Docker instalado"
else
    echo "✅ Docker ya está instalado"
fi
EOF

# 3. Clonar o actualizar repositorio
echo "📥 Clonando/actualizando repositorio..."
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << 'EOF'
if [ -d "smart-ops-infrastructure" ]; then
    echo "📂 Repositorio existe, actualizando..."
    cd smart-ops-infrastructure
    git pull
    git submodule update --remote --merge
else
    echo "📥 Clonando repositorio..."
    git clone --recursive https://github.com/vmestrada88/smart-ops-infrastructure.git
    cd smart-ops-infrastructure
fi
EOF

# 4. Copiar archivos de configuración de producción
echo "⚙️  Copiando Dockerfile de producción..."
scp -i "$KEY_PATH" Dockerfile.prod.frontend ubuntu@$EC2_IP:~/smart-ops-infrastructure/smart-ops-frontend/Dockerfile.prod
scp -i "$KEY_PATH" nginx.conf ubuntu@$EC2_IP:~/smart-ops-infrastructure/smart-ops-frontend/

# 5. Crear archivo .env de producción
echo "🔐 Configurando variables de entorno..."
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << EOF
cd smart-ops-infrastructure
cat > .env.production << 'ENVEOF'
POSTGRES_DB=smartsolution_production
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$(openssl rand -base64 32)

NODE_ENV=production
DB_HOST=db
DB_PORT=5432

VITE_API_URL=http://$EC2_IP:5000/api
ENVEOF

echo "✅ Variables de entorno configuradas"
EOF

# 6. Detener contenedores existentes
echo "🛑 Deteniendo contenedores existentes..."
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << 'EOF'
cd smart-ops-infrastructure
docker compose -f docker-compose.prod.yml down 2>/dev/null || true
EOF

# 7. Construir y levantar contenedores
echo "🏗️  Construyendo y levantando contenedores..."
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << 'EOF'
cd smart-ops-infrastructure
docker compose -f docker-compose.prod.yml up -d --build
EOF

# 8. Esperar a que los servicios estén listos
echo "⏳ Esperando a que los servicios inicien..."
sleep 10

# 9. Verificar estado
echo "🔍 Verificando estado de los contenedores..."
ssh -i "$KEY_PATH" ubuntu@$EC2_IP << 'EOF'
cd smart-ops-infrastructure
docker compose -f docker-compose.prod.yml ps
EOF

echo ""
echo "================================================"
echo "✅ ¡Despliegue completado!"
echo "================================================"
echo ""
echo "🌐 URLs de acceso:"
echo "   Frontend: http://$EC2_IP:5173"
echo "   Backend:  http://$EC2_IP:5000/api"
echo ""
echo "📊 Ver logs:"
echo "   ssh -i $KEY_PATH ubuntu@$EC2_IP"
echo "   cd smart-ops-infrastructure"
echo "   docker compose -f docker-compose.prod.yml logs -f"
echo ""
