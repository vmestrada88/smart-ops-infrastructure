# Smart Ops Infrastructure

Infrastructure as Code and deployment configurations for the Smart Ops ecosystem.

## Tech Stack

**Docker** · **AWS** · **Nginx** · **PostgreSQL** · **CI/CD**

## Components

- Docker Compose configuration for local development
- AWS App Runner service definitions
- Nginx reverse proxy configuration
- PostgreSQL schema management and migrations
- CI/CD pipeline scripts (GitHub Actions)

## Architecture

```
                   ┌─────────────┐
                   │   Nginx     │
                   │  (Reverse   │
                   │   Proxy)    │
                   └──────┬──────┘
                          │
              ┌───────────┴───────────┐
              │                       │
       ┌──────▼──────┐        ┌──────▼──────┐
       │  Frontend   │        │  Backend    │
       │  (Next.js)  │        │  (Express)  │
       └─────────────┘        └──────┬──────┘
                                      │
                               ┌──────▼──────┐
                               │ PostgreSQL  │
                               │  (Aurora)   │
                               └─────────────┘
```
