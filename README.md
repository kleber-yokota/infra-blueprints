# Infra Blueprints

A collection of ready-to-use Docker Compose templates for quickly spinning up daily development and data infrastructure.

## Network Architecture

This project uses two Docker networks to isolate and manage container communication:

| Network | Purpose |
|---------|---------|
| `internal` | Private communication between services that should not be exposed to the host (databases, caches, message brokers) |
| `external` | Public-facing services that need to be accessed from the host machine or outside containers (web servers, proxies, dashboards) |

```
 ┌──────────────────────────────────────────────┐
 │                  Host Machine                │
 │                                              │
 │   ┌─────────┐    ┌──────────────────────┐    │
 │   │ External│◄──►│  Web / Proxy / App   │    │
 │   └─────────┘    └──────────┬───────────┘    │
 │                              │                │
 │              ┌───────────────┼───────────────┐│
 │              │               │               ││
 │   ┌──────────▼──────────┐    │    ┌──────────▼──────────┐│
 │   │      internal       │    │    │      external       ││
 │   │  postgres:16        │    │    │  portainer:latest   ││
 │   │  redis:7-alpine     │    │    │  caddy:latest       ││
 │   │  postgres:15-repl   │    │    │  traefik:v3         ││
 │   └─────────────────────┘    │    └─────────────────────┘│
 │                              │               ▲           │
 │              ┌───────────────┼───────────────┤           │
 │              │               │               │           │
 │   ┌──────────▼──────────┐    │    ┌──────────▼──────────┐│
 │   │      internal       │    │    │      external       ││
 │   │  mysql:8            │    │    │  nginx:alpine       ││
 │   │  kafka:3.7          │    │    │  whoami:latest      ││
 │   └─────────────────────┘    │    └─────────────────────┘│
 └──────────────────────────────┴────────────────────────────┘
```

### Creating the Networks

If the networks don't exist on your machine, create them with:

```bash
docker network create internal
docker network create external
```

## Usage

Each directory contains a `docker-compose.yml` with pre-configured services.

```bash
# Navigate to a stack directory
cd <stack-name>

# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down
```

## Available Stacks

<!-- STACKS_START -->
<!-- STACKS_END -->

## Service Communication

### From `external` to `internal`

Services on the `external` network can reach `internal` services by container name.

### Isolated `internal` services

Services on the `internal` network can only communicate with other `internal` services.

## License

MIT
