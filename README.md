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
