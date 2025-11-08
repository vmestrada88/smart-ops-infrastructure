# Despliegue en AWS EC2

## 1. Crear instancia EC2

### Configuración recomendada:
- **AMI**: Ubuntu 24.04 LTS
- **Tipo de instancia**: t3.medium (2 vCPU, 4 GB RAM) o superior
- **Almacenamiento**: 30 GB SSD
- **Security Group**: Abrir puertos:
  - SSH (22) - Tu IP
  - HTTP (80) - 0.0.0.0/0
  - HTTPS (443) - 0.0.0.0/0
  - PostgreSQL (5432) - Solo si necesitas acceso externo
  - Backend (5000) - 0.0.0.0/0
  - Frontend (5173) - 0.0.0.0/0 (o usa nginx en puerto 80)

## 2. Conectarse a la instancia

```bash
chmod 400 smart-ops-docker-key.pem
ssh -i smart-ops-docker-key.pem ubuntu@<EC2_PUBLIC_IP>
```

## 3. Instalar Docker y Docker Compose

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario al grupo docker
sudo usermod -aG docker ubuntu

# Instalar Docker Compose
sudo apt install docker-compose-plugin -y

# Verificar instalación
docker --version
docker compose version

# Salir y volver a entrar para aplicar permisos
exit
```

## 4. Clonar el repositorio

```bash
# Conectarse nuevamente
ssh -i smart-ops-docker-key.pem ubuntu@<EC2_PUBLIC_IP>

# Instalar git
sudo apt install git -y

# Clonar con submodules
git clone --recursive https://github.com/vmestrada88/smart-ops-infrastructure.git
cd smart-ops-infrastructure
```

## 5. Configurar variables de entorno

```bash
# Crear archivo .env para producción
cat > .env.production << EOF
# Database
POSTGRES_DB=smartsolution_production
POSTGRES_USER=postgres
POSTGRES_PASSWORD=TU_PASSWORD_SEGURO_AQUI

# Backend
NODE_ENV=production
DB_HOST=db
DB_PORT=5432
DB_NAME=smartsolution_production
DB_USER=postgres
DB_PASSWORD=TU_PASSWORD_SEGURO_AQUI

# Frontend
VITE_API_URL=http://<EC2_PUBLIC_IP>:5000/api
EOF
```

## 6. Crear docker-compose para producción

Crea `docker-compose.prod.yml` (ver archivo)

## 7. Levantar los contenedores

```bash
# Levantar en producción
docker compose -f docker-compose.prod.yml up -d --build

# Ver logs
docker compose -f docker-compose.prod.yml logs -f

# Ver estado
docker compose -f docker-compose.prod.yml ps
```

## 8. Configurar Nginx como reverse proxy (Opcional pero recomendado)

```bash
sudo apt install nginx -y

# Crear configuración
sudo nano /etc/nginx/sites-available/smart-ops
```

```nginx
server {
    listen 80;
    server_name <TU_DOMINIO_O_IP>;

    # Frontend
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Habilitar sitio
sudo ln -s /etc/nginx/sites-available/smart-ops /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 9. Configurar SSL con Let's Encrypt (Producción)

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d tu-dominio.com
```

## 10. Actualizar la aplicación

```bash
cd smart-ops-infrastructure

# Pull cambios
git pull

# Actualizar submodules
git submodule update --remote --merge

# Reconstruir y reiniciar
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d --build
```

## 11. Monitoreo y logs

```bash
# Ver logs en tiempo real
docker compose -f docker-compose.prod.yml logs -f

# Ver logs de un servicio específico
docker compose -f docker-compose.prod.yml logs -f back-end

# Ver recursos
docker stats

# Ver estado de contenedores
docker ps
```

## 12. Backup de la base de datos

```bash
# Crear backup
docker exec smart-ops-db pg_dump -U postgres smartsolution_production > backup_$(date +%Y%m%d).sql

# Restaurar backup
cat backup_20250108.sql | docker exec -i smart-ops-db psql -U postgres smartsolution_production
```

## Troubleshooting

### Si los contenedores no inician:
```bash
docker compose -f docker-compose.prod.yml logs
```

### Si hay problemas de permisos:
```bash
sudo chown -R ubuntu:ubuntu smart-ops-infrastructure
```

### Si hay problemas de red:
```bash
# Verificar security group en AWS
# Verificar firewall
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 5000
```

## Costos aproximados (us-east-1)

- **t3.medium**: ~$30/mes
- **30 GB EBS**: ~$3/mes
- **Elastic IP**: Gratis si está asignado
- **Transfer**: Variable según tráfico

**Total aproximado**: $35-50/mes
