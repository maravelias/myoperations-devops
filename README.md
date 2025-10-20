# Local Development Stack (Docker Compose)

This folder contains a complete, containerized development environment for the project. It provides databases, auth, code quality, monitoring, logging, visualization, and developer utilities so you can develop and test locally with minimal setup.

Services are orchestrated with Docker Compose and are pre-configured to work together out of the box.

## Prerequisites
- Docker Engine 24+ (or Docker Desktop 4.30+)
- Docker Compose v2
- Recommended resources:
  - CPU: 4+ cores
  - RAM: 8 GB (minimum 6 GB)
  - Disk: 20+ GB free (volumes: Postgres, SonarQube, Prometheus, Loki, Grafana)
- Ports available on host: 3000, 3100, 5050, 5080, 5432, 8025, 9000, 9090, 1025

Security note: Default credentials and static IPs are used for local development only. Do not reuse in any shared or production environment.

## What's Included
- Postgres 17 with pgvector (DB: operations)
- pgAdmin 4 (pre-provisioned connection to Postgres)
- Keycloak 26 (realm import: MyOperations)
- SonarQube (LTS) with dedicated Postgres DB
- Prometheus (metrics)
- Loki (log aggregation)
- Grafana OSS (dashboards; pre-provisioned datasources for Prometheus & Loki)
- MailHog (test SMTP + web UI)

Network: A dedicated bridge network `myoperations-network` (172.30.0.0/24) with static container IPs.

## Quick Start
From repository root:

- Start all services (detached):
```bash
docker compose -f devops/local/docker-compose.yml up -d
```

- Stop and remove containers (keep volumes):
```bash
docker compose -f devops/local/docker-compose.yml down
```

- Tail logs for all services:
```bash
docker compose -f devops/local/docker-compose.yml logs -f
```

- Tail logs for one service (e.g., keycloak):
```bash
docker compose -f devops/local/docker-compose.yml logs -f keycloak
```

- Recreate from scratch (CAUTION – removes named volumes):
```bash
docker compose -f devops/local/docker-compose.yml down
docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
docker compose -f devops/local/docker-compose.yml up -d
```

Note: `docker compose down -v` does not remove named volumes; remove explicitly as above.

## Service Endpoints and Credentials
- Postgres
  - Host (from host): `localhost:5432`
  - Host (from containers): `postgres:5432` (service DNS)
  - DB: `operations`
  - Username: `postgres`
  - Password: `P@ssw0rd`

- pgAdmin
  - URL: `http://localhost:5050`
  - Login: `admin@local.com` / `admin`
  - Pre-provisioned server: PostgreSQL Server (points to `172.30.0.10`)

- Keycloak
  - URL: `http://localhost:5080`
  - Admin: `admin` / `admin`
  - Realm: `MyOperations` (auto-imported at first start)
  - Sample users:
    - `admin` / `admin` (role `SYSADM`)
    - `sr1` / `password` (role `SR`)
    - `pm1` / `password` (role `PM`)
  - OAuth clients:
    - `myoperations-frontend` (public)
    - `myoperations-backend` (confidential; secret: `changeme-in-prod`)

- SonarQube
  - URL: `http://localhost:9000`
  - First login: `admin` / `admin` (you will be asked to change the password)
  - DB: standalone Postgres service (`sonar-db`)
  - Create a token: User menu → My Account → Security → Generate Token
  - Local scan options:
    - Maven/Gradle plugins (preferred for JVM projects)
    - CLI via Docker:
      ```bash
      docker run --rm \
        -e SONAR_HOST_URL=http://host.docker.internal:9000 \
        -e SONAR_LOGIN=<token> \
        -v "$(pwd)":/usr/src \
        sonarsource/sonar-scanner-cli
      ```

- Prometheus
  - URL: `http://localhost:9090`
  - Scrapes itself and a local app at `:8080` by default; see Prometheus section below.

- Loki
  - API: `http://localhost:3100`

- Grafana
  - URL: `http://localhost:3000`
  - Login: `admin` / `admin`
  - Datasources: Prometheus and Loki are pre-provisioned via `grafana/provisioning`

- MailHog
  - SMTP (from host): `localhost:1025`
  - SMTP (from containers): `mailhog:1025` (service DNS)
  - UI: `http://localhost:8025`

## Prometheus and Your Application
The Prometheus configuration at `devops/local/prometheus/prometheus.yml` includes a job to scrape a local application exposing Micrometer metrics at `/actuator/prometheus`.

- Linux hosts: The config targets `172.17.0.1:8080` (Docker bridge IP). Ensure your app runs on the host at port `8080` and exposes `/actuator/prometheus`.
- macOS/Windows (Docker Desktop): Use `host.docker.internal:8080` instead. In `prometheus.yml`, uncomment the `host.docker.internal` line and comment/remove the `172.17.0.1` target.

Quick checks:
- Verify app metrics locally:
  ```bash
  curl -f http://localhost:8080/actuator/prometheus | head
  ```
- Verify Prometheus can reach the app: open `http://localhost:9090`, go to Status → Targets, check the `operations-app` job.

## Health Checks and Readiness
- Check container health:
  ```bash
  docker ps --format 'table {{.Names}}\t{{.Status}}'
  ```
- Individual service inspect (e.g., postgres):
  ```bash
  docker inspect --format='{{json .State.Health}}' myoperations-postgres | jq
  ```
Keycloak and SonarQube may take 1–3 minutes on first start (initialization and realm import).

## Troubleshooting
- Port conflicts: If a port is already in use, stop the conflicting service or change the published port in `devops/local/docker-compose.yml`.
- Network/subnet conflicts: If `172.30.0.0/24` overlaps with your environment, change the `myoperations-network` subnet and the fixed container IPs consistently across services.
- SonarQube on Linux: You may need to increase `vm.max_map_count` for the embedded search engine:
  ```bash
  sudo sysctl -w vm.max_map_count=262144
  echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-sonarqube.conf
  ```
- File permissions on Linux: If volumes create permission issues, ensure your user can access Docker-managed volumes or adjust directory ownership inside containers where appropriate.
- Keycloak realm import didn’t apply: Ensure first startup was clean (no existing `/opt/keycloak` data volume). Remove the `myoperations-keycloak` container and recreate. The compose file mounts `./keycloak/MyOperations-realm.json` read-only for import with `start-dev --import-realm`.
- Prometheus can’t scrape app: Confirm the correct target for your OS (`172.17.0.1` vs `host.docker.internal`) and that the app exposes metrics on `/actuator/prometheus`.

## Data Persistence
Named Docker volumes keep data across restarts:
- `postgres-data`, `sonar-db-data`, `sonar-data`, `sonar-extensions`, `prometheus-data`, `grafana-storage`, `loki-data`, `pgadmin-data`

Remove named volumes only if you want to reset state (see “Recreate from scratch”).

Compose project name
- This stack sets the Compose project name to `myoperations-local-stack` (see `name:` in `devops/local/docker-compose.yml`).
- Docker Compose prefixes created resource names (volumes, networks) with the project name.
- That’s why volume names in cleanup examples start with `myoperations-local-stack_`.

## Service Inventory (from docker-compose.yml)
- Postgres 17 (pgvector) (myoperations-postgres) – 172.30.0.10:5432
- pgAdmin 4 9.8.0 (myoperations-pgadmin) – http://localhost:5050
- Keycloak 26.3.3 (myoperations-keycloak) – http://localhost:5080
- Sonar DB (Postgres 17) (myoperations-sonar-db) – internal only
- SonarQube LTS (myoperations-sonarqube) – http://localhost:9000
- Prometheus v2.54.1 (myoperations-prometheus) – http://localhost:9090
- Loki 2.9.8 (myoperations-loki) – http://localhost:3100
- Grafana OSS 12.1.1 (myoperations-grafana) – http://localhost:3000
- MailHog (myoperations-mailhog) – http://localhost:8025, SMTP 1025

## Remote VM Deployment (Ubuntu)
If you have an Ubuntu VM with SSH access and want to deploy this stack there, you have two options:

- Script (simple): copy the repo to the VM and run the deploy script as root
  1) Copy repo (example):
     ```bash
     scp -r . <user>@<vm>:/opt/MyOperations-Docs
     ```
  2) SSH into the VM and run:
     ```bash
     sudo bash /opt/MyOperations-Docs/devops/local/scripts/deploy-to-vm.sh \
       --with-systemd --repo-dir /opt/MyOperations-Docs --user <user>
     ```
  The script installs Docker Engine + Compose plugin, applies the SonarQube sysctl, brings up the stack, and optionally installs a systemd unit to auto-start on boot.

- Ansible (idempotent): from your machine, with Ansible installed
  1) Edit inventory: `devops/local/ansible/inventory.ini`
  2) Run playbook:
     ```bash
     ansible-playbook -i devops/local/ansible/inventory.ini devops/local/ansible/site.yml
     ```
  The playbook installs Docker and dependencies, syncs the repo to `/opt/MyOperations-Docs`, starts the stack, and creates a systemd unit.

Notes
- Network subnet: The compose file uses a fixed subnet `172.30.0.0/24`. If this conflicts on your VM, adjust the subnet and static IPs in `devops/local/docker-compose.yml` under the `myoperations-network` section.
- Firewall: Ensure the VM allows inbound ports you need (e.g., 3000, 5080, 9000, 8025, 9090, 5432) or restrict to your IP.
- Non-root docker use: After first run, the user added to the docker group must re-login for permissions to take effect.

## Cleanup
To remove everything created by this stack:
```bash
docker compose -f devops/local/docker-compose.yml down
docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
```

---
If you encounter issues not covered here, please open an issue with your OS, Docker version, and logs from the failing service (`docker compose ... logs -f <service>`).

## Document Version History
| Version | Date/Time  | Author             | Changes                                                                 |
|-------:|------------|--------------------|-------------------------------------------------------------------------|
| 1.0    | 2025-08-22 | Giorgos Maravelias | Initial README for local Docker-based development stack                 |
| 1.1    | 2025-08-22 | Giorgos Maravelias | Added Version History, Folder structure, System Overview, Docker commands |
| 1.2    | 2025-10-20 | Giorgos Maravelias | Verified SonarQube and MailHog in compose; aligned versions; added usage notes |
| 1.3    | 2025-10-20 | Giorgos Maravelias | Added VM deployment script and Ansible playbook; README VM section      |
| 1.5    | 2025-10-20 | Giorgos Maravelias | Cleaned up formatting; refocused on local dev; added pgvector note      |

## Folder Structure
```
devops/local/
├── README.md                       # Documentation for the local Docker setup
├── docker-compose.yml              # Orchestrates all local services
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasource.yml      # Pre-provisioned Prometheus and Loki datasources
├── keycloak/
│   └── MyOperations-realm.json     # Realm, roles, users, and clients for MyOperations
├── loki/
│   └── config.yml                  # Loki configuration for single-process mode
├── pgadmin/
│   └── servers.json                # Preconfigured server connection to Postgres
├── prometheus/
│   └── prometheus.yml              # Prometheus scrape configuration (self + local app)
└── logs/                           # Optional directory for local logs/mounts
```

## System Overview
This local environment provides an integrated platform to develop and validate the Operations application and its operational concerns:

- Core services
  - Postgres: Primary relational database for the application (DB: operations)
  - Keycloak: Identity and Access Management (OpenID Connect), with pre-imported MyOperations realm
  - SonarQube + Sonar DB: Static code analysis and quality gates
  - Prometheus: Metrics collection; scrapes itself and the local application
  - Loki: Log aggregation backend for structured logs
  - Grafana: Visualization of metrics and logs (datasources pre-provisioned)
  - MailHog: Test SMTP server with web UI for capturing outgoing emails
  - pgAdmin: GUI for Postgres

- Networking
  - All services run on the `myoperations-network` bridge (172.30.0.0/24) with stable container IPs
  - Host-accessible ports are published as listed in the Service Endpoints section
  - Within the network, use service DNS names (e.g., `postgres`, `mailhog`) for inter-container connections; avoid relying on `container_name` or static IPs

- Typical flows
  - Application → Postgres for data persistence
  - Application → Keycloak for authentication/authorization (OIDC)
  - Prometheus → Application `/actuator/prometheus` for metrics scraping
  - Application/Services → stdout/stderr → Docker logs → Loki (future via Promtail or direct integration)
  - Grafana → Prometheus/Loki for dashboards and log exploration
  - Developers → SonarQube for code quality analysis
  - Application → MailHog for testing email flows

## Common Docker Commands
Frequent docker and docker compose commands for this environment (run from repository root):

- Start stack (detached):
  ```bash
  docker compose -f devops/local/docker-compose.yml up -d
  ```
- Stop and remove containers (keep volumes):
  ```bash
  docker compose -f devops/local/docker-compose.yml down
  ```
- Recreate from scratch (removes named volumes; destructive):
  ```bash
  docker compose -f devops/local/docker-compose.yml down
  docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
  docker compose -f devops/local/docker-compose.yml up -d
  ```
- Status and logs:
  ```bash
  docker compose -f devops/local/docker-compose.yml ps
  docker compose -f devops/local/docker-compose.yml logs -f
  docker compose -f devops/local/docker-compose.yml logs -f <service>
  ```
- Exec into a container shell (example Postgres):
  ```bash
  docker exec -it myoperations-postgres bash
  ```
- Health and inspection:
  ```bash
  docker ps --format 'table {{.Names}}\t{{.Status}}'
  docker inspect --format='{{json .State.Health}}' myoperations-postgres | jq
  ```
- Volumes, networks, cleanup:
  ```bash
  docker volume ls
  docker volume rm <volume>
  docker network ls
  docker network inspect myoperations-network
  docker system prune -f
  ```

## Optional Make Targets
For convenience, a `Makefile` is provided in the repo root that wraps common commands:

- Start stack: `make up`
- Stop stack: `make down`
- Tail logs (all): `make logs`
- Tail logs (one): `make logs-keycloak`
- List services: `make ps`
- Validate compose: `make config`
- Reset (remove project volumes): `make reset`
