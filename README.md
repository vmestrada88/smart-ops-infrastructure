# Smart Ops Infrastructure

Esta carpeta contiene la configuración y scripts para desplegar Smart Ops en EC2.

## Archivos principales

- `docker-compose.prod.yml`: stack de producción (DB + backend + frontend)
- `.env.production.sample`: plantilla de variables para EC2/producción
- `ec2-update.sh`: actualiza código, submodules y levanta contenedores en EC2
- `deploy.sh`: wrapper de un comando para ejecutar `ec2-update.sh`
- `setup-nginx.sh`: configura Nginx host como reverse proxy
- `setup-ssl.sh`: configura SSL con Let's Encrypt

## Despliegue rápido en EC2

```bash
cd ~/smart-ops-infrastructure
cp .env.production.sample .env
# editar .env con secretos reales
chmod +x deploy.sh ec2-update.sh setup-nginx.sh setup-ssl.sh
./deploy.sh
```

Guía completa: ver `deploy-ec2.md`.

## Deploy automático a EC2 (GitHub Actions)

Este repo incluye el workflow `deploy-production-ec2.yml` que se ejecuta en:

- push a la rama `production`
- ejecución manual (`workflow_dispatch`)

Para habilitarlo, configura estos secretos en GitHub (repo `smart-ops-infrastructure`):

- `EC2_HOST` (ejemplo: IP pública o dominio del servidor)
- `EC2_USER` (ejemplo: `ubuntu`)
- `EC2_SSH_PRIVATE_KEY` (llave privada PEM, contenido completo)

Opcionales:

- `EC2_SSH_PORT` (por defecto `22`)
- `EC2_APP_DIR` (por defecto `~/smart-ops-infrastructure`)

El workflow hace SSH al servidor y ejecuta `./deploy.sh` en `production`.
