# Deploy en EC2 (Producción)

## 1) Requisitos en la instancia

- Ubuntu 22.04+ (recomendado)
- Docker y Docker Compose Plugin
- Git
- Puertos abiertos en Security Group: `22`, `80`, `443`, `5000` (opcional para debug)
- DNS del dominio apuntando a la IP pública de EC2

## 2) Clonar repositorio de infraestructura

```bash
cd ~
git clone <REPO_INFRA_URL> smart-ops-infrastructure
cd smart-ops-infrastructure
git checkout production
```

> Si ya existe, usa `git pull origin production`.

## 3) Configurar acceso a GHCR (si imágenes privadas)

```bash
export GHCR_USER="tu_usuario_github"
export GHCR_TOKEN="tu_token_con_read_packages"
```

## 4) Crear archivo de variables de producción

```bash
cp .env.production.sample .env
nano .env
```

Ajusta al menos:
- `POSTGRES_PASSWORD`
- `DB_PASSWORD`
- `JWT_SECRET`
- `FRONTEND_URLS`

## 5) Ejecutar despliegue

```bash
chmod +x deploy.sh ec2-update.sh
./deploy.sh
```

Esto hace:
- `git pull` de `production`
- `git submodule update --init --recursive`
- restaura backup SQL si existe en `~/db_backup_*.sql`
- `docker compose -f docker-compose.prod.yml pull`
- `docker compose -f docker-compose.prod.yml up -d --no-build`

## 6) Configurar Nginx y SSL

```bash
chmod +x setup-nginx.sh setup-ssl.sh
./setup-nginx.sh
./setup-ssl.sh
```

## 7) Verificación

```bash
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f
curl -I http://localhost:8080
curl -I http://localhost:5000/api/health
```

## 8) Actualizaciones futuras

```bash
cd ~/smart-ops-infrastructure
./deploy.sh
```
