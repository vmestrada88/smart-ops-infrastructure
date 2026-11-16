# Smart Ops Infrastructure

Esta carpeta contiene la configuración y scripts para desplegar Smart Ops en EC2.

## Archivos principales

- `docker-compose.prod.yml`: stack de producción (DB + backend + frontend)
- `.env.production.sample`: plantilla de variables para EC2/producción
- `ec2-update.sh`: hace backup de la base, descarga las imágenes nuevas de GHCR y reinicia backend/frontend (nunca borra volúmenes)
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

### Cómo llega un cambio a producción

1. Trabajas en `dev` y promueves con PRs: `dev → test → staging → production` (a `production` solo se permite desde `staging`).
2. Al hacer merge a `production` en **smart-ops-backend** o **smart-ops-frontend**, su workflow `publish-image.yml` construye la imagen en GHCR y luego dispara este workflow con `service=back-end` o `service=front-end`.
3. Este workflow entra al EC2 y corre `ec2-update.sh`, que:
   - guarda un backup `~/backups/pre-deploy-<fecha>.sql.gz` (conserva los últimos 7),
   - descarga la imagen nueva y reinicia solo ese servicio,
   - verifica `/api/health` y, si falla, vuelve a la imagen anterior.
4. Un merge a `production` en este repo despliega todo (`service=all`).

Para que backend y frontend puedan disparar este workflow, cada uno necesita el secret `INFRA_DEPLOY_TOKEN`: un fine-grained token de GitHub con acceso a `smart-ops-infrastructure` y permiso **Actions: Read and write**. Sin ese secret la imagen se publica igual y el workflow avisa que hay que correr el deploy a mano.

### Restaurar un backup (manual)

```bash
gunzip -c ~/backups/pre-deploy-AAAAMMDD-HHMMSS.sql.gz | docker exec -i smart-ops-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Postgres (5432), la API (5000) y el frontend (8080) solo escuchan en `127.0.0.1`; el tráfico público entra por Nginx del host (`setup-nginx.sh`).
