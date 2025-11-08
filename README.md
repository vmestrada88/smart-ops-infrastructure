# Smart Ops Infrastructure

Este repositorio contiene la configuración de infraestructura para el proyecto Smart Ops.

## Estructura

```
smart-ops-infrastructure/
├── docker-compose.yml          # Configuración de Docker para desarrollo
├── smart-ops-backend/          # Submodule del backend
├── smart-ops-frontend/         # Submodule del frontend
└── smart-ops-mobile/           # Submodule del mobile
```

## Clonar el proyecto completo

```bash
# Clonar con todos los submodules
git clone --recursive https://github.com/vmestrada88/smart-ops-infrastructure.git

# Si ya clonaste sin --recursive
git submodule update --init --recursive
```

## Levantar el entorno de desarrollo

```bash
docker compose up -d
```

## Actualizar submodules

```bash
git submodule update --remote
```

## Servicios

- **Backend**: http://localhost:5000
- **Frontend**: http://localhost:5173
- **Database**: PostgreSQL en puerto 5432
