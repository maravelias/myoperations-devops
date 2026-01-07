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
- Ports available on host: 80, 3000, 3100, 5050, 5080, 5432, 8025, 9000, 9090, 1025

Security note: Default credentials and static IPs are used for local development only. Do not reuse in any shared or production environment.

## Clone the Repository (Linux CLI)
```bash
git clone https://github.com/maravelias/myoperations-devops.git
cd myoperations-devops
```
- Requires `git` (install via your distro’s package manager, e.g., `sudo apt install git`).
- To stay up to date later, run `git pull` inside the repo or use `bash local-dev/scripts/update-stack.sh`.

## What's Included
- Postgres 18 with pgvector (DB: operations)
- pgAdmin 4 (pre-provisioned connection to Postgres)
- Keycloak 26.5 (realm import: MyOperations)
- SonarQube (Community) with dedicated Postgres DB
- Prometheus (metrics)
- Loki (log aggregation)
- Grafana OSS (dashboards; pre-provisioned datasources for Prometheus & Loki)
- MailHog (test SMTP + web UI)
- Nginx (welcome page on port 80)

Network: A dedicated bridge network `myoperations-network` (172.30.0.0/24) with static container IPs.

## Quick Start
From repository root:

- Start all services (detached):
```bash
docker compose -f local-dev/docker-compose.yml up -d
```

- Stop and remove containers (keep volumes):
```bash
docker compose -f local-dev/docker-compose.yml down
```

- Tail logs for all services:
```bash
docker compose -f local-dev/docker-compose.yml logs -f
```

- Tail logs for one service (e.g., keycloak):
```bash
docker compose -f local-dev/docker-compose.yml logs -f keycloak
```

- Recreate from scratch (CAUTION – removes named volumes):
```bash
docker compose -f local-dev/docker-compose.yml down
docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
docker compose -f local-dev/docker-compose.yml up -d
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
  - Login theme: `myoperations` (files under `local-dev/keycloak/themes/myoperations`; edit CSS/messages for branding)
  - Database: Postgres service `postgres:5432`, DB `keycloak`, username/password `keycloak`
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
  - Auth: disabled (`auth_enabled: false`) for single-tenant local dev; no X-Scope-OrgID header required

- Grafana
  - URL: `http://localhost:3000`
  - Login: `admin` / `admin`
  - Datasources: Prometheus and Loki are pre-provisioned via `grafana/provisioning`.
    Note: the Loki datasource points to the fixed container IP `172.30.0.15:3100`
    to match the static network; update if you change the subnet or Loki IP.

- Nginx
  - URL: `http://localhost/`
  - Purpose: Serves a simple welcome page for the local stack
  - Files: `local-dev/nginx/html/index.html` (mounted read-only)

- MailHog
  - SMTP (from host): `localhost:1025`
  - SMTP (from containers): `mailhog:1025` (service DNS)
  - UI: `http://localhost:8025`

## Custom Keycloak Theme
- Theme name: `myoperations`; mounted into the Keycloak container from `local-dev/keycloak/themes/myoperations`.
- Contents:
  - `login/theme.properties` pins the parent theme (`keycloak.v2`) and loads `resources/css/myoperations.css`.
  - `login/resources/css/myoperations.css` defines the ivory/gold palette, hero layout, and form controls.
  - `login/resources/messages/messages_en.properties` overrides login copy (title/button text/hero content).
  - `login/resources/login.ftl` customizes the login form markup (remember-me, password toggle, register CTA).
  - `login/resources/template.ftl` controls the two-column layout, hero copy, and locale dropdown wrapper.
  - `login/resources/img/logo.png` is the header logo used in the theme (replace this file to update branding).
- Realm import (`local-dev/keycloak/MyOperations-realm.json`) sets `loginTheme` to `myoperations`. If your Keycloak database already existed before this change, either update the realm via the Keycloak Admin Console (Realm Settings → Themes → Login) or reset the Postgres `keycloak` schema to re-import.
- To tweak the visuals:
  1. Edit the files under `local-dev/keycloak/themes/myoperations`.
  2. Restart Keycloak so it reloads the static resources:
     ```bash
     docker compose -f local-dev/docker-compose.yml up -d keycloak
     ```
  3. Hard-refresh your browser (or open in a private window) to avoid cached CSS.

## Prometheus and Your Application
The Prometheus configuration at `local-dev/prometheus/prometheus.yml` includes a job (`myoperations-app`) to scrape a local application exposing Micrometer metrics at `/actuator/prometheus` on port `8080`.

- Linux hosts: The config includes `172.17.0.1:8080` (default Docker bridge) and `172.30.0.1:8080` (the custom bridge gateway used by `myoperations-network`). Ensure your app runs on the host at port `8080` and exposes `/actuator/prometheus`.
- macOS/Windows (Docker Desktop): Use `host.docker.internal:8080` (the line is present but commented). Uncomment it if needed and remove/comment others to avoid duplicates.
- Other setups: `192.168.56.1:8080` is included for common host‑only adapters (e.g., VirtualBox). Comment out any targets that don’t apply to your environment.

Quick checks:
- Verify app metrics locally:
  ```bash
  curl -f http://localhost:8080/actuator/prometheus | head
  ```
- Verify Prometheus can reach the app: open `http://localhost:9090`, go to Status → Targets, check the `myoperations-app` job.

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
- Port conflicts: If a port is already in use, stop the conflicting service or change the published port in `local-dev/docker-compose.yml`.
- If port 80 is in use (Nginx), change the mapping to `8080:80` and access via `http://localhost:8080/`.
- Network/subnet conflicts: If `172.30.0.0/24` overlaps with your environment, change the `myoperations-network` subnet and the fixed container IPs consistently across services.
  If you change the subnet or IPs, also update `local-dev/grafana/provisioning/datasources/datasource.yml` (Loki datasource URL) and `local-dev/loki/config.yml` (Loki instance_addr) to match.
 - Grafana → Loki 401 ("no org id"): Loki runs single-tenant for local dev. Ensure `auth_enabled: false` in `local-dev/loki/config.yml` and restart Loki/Grafana:
   ```bash
   docker compose -f local-dev/docker-compose.yml up -d loki grafana
   ```
- SonarQube on Linux: You may need to increase `vm.max_map_count` for the embedded search engine:
  ```bash
  sudo sysctl -w vm.max_map_count=262144
  echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-sonarqube.conf
  ```
- File permissions on Linux: If volumes create permission issues, ensure your user can access Docker-managed volumes or adjust directory ownership inside containers where appropriate.
- Keycloak realm import didn’t apply: Ensure first startup was clean (no existing `/opt/keycloak` data volume). Remove the `myoperations-keycloak` container and recreate. The compose file mounts `./keycloak/MyOperations-realm.json` read-only for import with `start-dev --import-realm`.
- Resetting Keycloak data: All state lives in the Postgres `keycloak` database. Drop that database/user (or remove the `postgres-data` volume) to force a clean realm import on the next startup.
- Prometheus can’t scrape app: Confirm the correct target for your OS (`172.17.0.1` vs `host.docker.internal`) and that the app exposes metrics on `/actuator/prometheus`.

## Data Persistence
Named Docker volumes keep data across restarts:
- `postgres-data`, `sonar-db-data`, `sonar-data`, `sonar-extensions`, `prometheus-data`, `grafana-storage`, `loki-data`, `pgadmin-data`

Remove named volumes only if you want to reset state (see “Recreate from scratch”).
Keycloak persistence is part of the shared `postgres-data` volume, so wiping it also removes the `keycloak` database/user.

Compose project name
- This stack sets the Compose project name to `myoperations-local-stack` (see `name:` in `local-dev/docker-compose.yml`).
- Docker Compose prefixes created resource names (volumes, networks) with the project name.
- That’s why volume names in cleanup examples start with `myoperations-local-stack_`.

## Service Inventory (from docker-compose.yml)
- Postgres 18 (pgvector) (myoperations-postgres) – 172.30.0.10:5432
- pgAdmin 4 9.11.0 (myoperations-pgadmin) – http://localhost:5050
- Keycloak 26.5.0 (myoperations-keycloak) – http://localhost:5080
- Sonar DB (Postgres 18.1) (myoperations-sonar-db) – internal only
- SonarQube Community 26.1.0.118079 (myoperations-sonarqube) – http://localhost:9000
- Prometheus v3.9.0 (myoperations-prometheus) – http://localhost:9090
- Loki 3.6.3 (myoperations-loki) – http://localhost:3100
- Grafana OSS 12.3.1 (myoperations-grafana) – http://localhost:3000
- MailHog (myoperations-mailhog) – http://localhost:8025, SMTP 1025
- Nginx 1.29.4-alpine (myoperations-nginx) – http://localhost

## Remote VM Deployment (Ubuntu)
If you have an Ubuntu VM with SSH access and want to deploy this stack there, you have two options:

- Script (simple): copy the repo to the VM and run the deploy script as root
  1) Copy repo (example):
     ```bash
     scp -r . <user>@<vm>:/opt/myoperations-devops
     ```
  2) SSH into the VM and run:
     ```bash
     sudo bash /opt/myoperations-devops/local-dev/scripts/deploy-to-vm.sh \
       --with-systemd --repo-dir /opt/myoperations-devops --user <user>
     ```
  The script installs Docker Engine + Compose plugin, applies the SonarQube sysctl, brings up the stack, and optionally installs a systemd unit to auto-start on boot.

- Ansible (idempotent): from your machine, with Ansible installed
  1) Edit inventory: `local-dev/ansible/inventory.ini`
  2) Run playbook:
     ```bash
     ansible-playbook -i local-dev/ansible/inventory.ini local-dev/ansible/site.yml
     ```
  The playbook installs Docker and dependencies, syncs the repo to `/opt/myoperations-devops`, starts the stack, and creates a systemd unit.

Notes
- Network subnet: The compose file uses a fixed subnet `172.30.0.0/24`. If this conflicts on your VM, adjust the subnet and static IPs in `local-dev/docker-compose.yml` under the `myoperations-network` section.
- Firewall: Ensure the VM allows inbound ports you need (e.g., 3000, 5080, 9000, 8025, 9090, 5432) or restrict to your IP.
- Non-root docker use: After first run, the user added to the docker group must re-login for permissions to take effect.

## Updating Configuration
When you change configuration under `local-dev/` (Compose file, Prometheus/Loki/Grafana configs, Keycloak realm, etc.), apply updates as follows.

- Validate changes first:
  ```bash
  docker compose -f local-dev/docker-compose.yml config
  ```

- Local (Docker Compose on your machine):
  - Config/provisioning changes only (e.g., Prometheus, Loki, Grafana): restart affected services to pick up mounted files.
    ```bash
    docker compose -f local-dev/docker-compose.yml up -d prometheus
    docker compose -f local-dev/docker-compose.yml up -d loki
    docker compose -f local-dev/docker-compose.yml up -d grafana
    ```
    Note: Prometheus hot reload is not enabled by default; a container restart is required after editing `prometheus.yml`.
  - Image tag changes: pull new images, then recreate containers.
    ```bash
    docker compose -f local-dev/docker-compose.yml pull
    docker compose -f local-dev/docker-compose.yml up -d
    ```
  - Network/subnet/static IP changes: recreate the network.
    ```bash
    docker compose -f local-dev/docker-compose.yml down
    docker compose -f local-dev/docker-compose.yml up -d
    ```

- VM (systemd-managed deployment):
  If you deployed with `local-dev/scripts/deploy-to-vm.sh --with-systemd` or via Ansible, a Linux service `myoperations-local-stack.service` is installed. Update the files on the VM (e.g., under `/opt/myoperations-devops`) and then:
  - Restart to apply config changes:
    ```bash
    sudo systemctl restart myoperations-local-stack.service
    ```
  - If image tags changed, pull first:
    ```bash
    cd /opt/myoperations-devops && sudo docker compose -f local-dev/docker-compose.yml pull
    sudo systemctl restart myoperations-local-stack.service
    ```
  - If network/subnet changed, do a clean down/up cycle:
    ```bash
    sudo systemctl stop myoperations-local-stack.service
    sudo docker compose -f /opt/myoperations-devops/local-dev/docker-compose.yml down
    sudo systemctl start myoperations-local-stack.service
    ```
  Alternatively, rerun the Ansible playbook to sync files and restart:
  ```bash
  ansible-playbook -i local-dev/ansible/inventory.ini local-dev/ansible/site.yml
  ```

Persistence note: Some services initialize state on first start (e.g., Keycloak realm import, SonarQube data). If those assets change and you need a clean re-import, you may need to reset the corresponding named volumes. See “Recreate from scratch”.

## Cleanup
Use these procedures to remove the stack. Choose the scope that fits your case.

- Local (Compose only; keep data):
  ```bash
  docker compose -f local-dev/docker-compose.yml down
  ```

- Local (full reset; removes named volumes – destructive):
  ```bash
  docker compose -f local-dev/docker-compose.yml down
  docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
  # Optional: remove the dedicated network if unused elsewhere
  docker network rm myoperations-network 2>/dev/null || true
  ```

- VM (systemd-managed deployment; manual removal):
  1) Stop and remove the Linux service
  ```bash
  sudo systemctl stop myoperations-local-stack.service || true
  sudo systemctl disable myoperations-local-stack.service || true
  sudo rm -f /etc/systemd/system/myoperations-local-stack.service
  sudo systemctl daemon-reload
  sudo systemctl reset-failed || true
  ```
  2) Bring the stack down and remove data (adjust repo path if different)
  ```bash
  sudo docker compose -f /opt/myoperations-devops/local-dev/docker-compose.yml down
  sudo docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
  sudo docker network rm myoperations-network 2>/dev/null || true
  ```
  3) Optionally remove the deployed files
  ```bash
  sudo rm -rf /opt/myoperations-devops
  ```

- Automated (script):
  - Local machine:
    ```bash
    bash local-dev/scripts/cleanup.sh --local --remove-volumes --remove-network
    ```
  - VM (service installed):
    ```bash
    sudo bash local-dev/scripts/cleanup.sh --vm --repo-dir /opt/myoperations-devops \
      --remove-volumes --remove-network --purge-repo
    ```

---
If you encounter issues not covered here, please open an issue with your OS, Docker version, and logs from the failing service (`docker compose ... logs -f <service>`).

## Document Version History
| Version | Date/Time  | Author             | Changes                                                                 |
|--------:|------------|--------------------|-------------------------------------------------------------------------|
|     1.0 | 2025-08-22 | Giorgos Maravelias | Initial README for local Docker-based development stack                 |
|     1.1 | 2025-08-22 | Giorgos Maravelias | Added Version History, Folder structure, System Overview, Docker commands |
|     1.2 | 2025-10-20 | Giorgos Maravelias | Verified SonarQube and MailHog in compose; aligned versions; added usage notes |
|     1.3 | 2025-10-20 | Giorgos Maravelias | Added VM deployment script and Ansible playbook; README VM section      |
|     1.5 | 2025-10-20 | Giorgos Maravelias | Cleaned up formatting; refocused on local dev; added pgvector note      |
|     1.6 | 2025-10-20 | Giorgos Maravelias | Normalized paths to local-dev; aligned VM/Ansible; updated SonarQube wording; removed Makefile section |
|     1.7 | 2025-10-22 | Giorgos Maravelias | Consolidated updates: aligned docs with config (Prometheus job `myoperations-app`, extra targets 172.30.0.1/192.168.56.1, Loki/Grafana static IP note); added “Updating Configuration” section with systemd workflow; expanded Cleanup (service removal, network); moved cleanup script to `local-dev/scripts/cleanup.sh` |
|     1.8 | 2025-10-22 | Giorgos Maravelias | Added Nginx welcome page service (port 80), updated ports/endpoints, folder structure, and troubleshooting notes |
|     1.9 | 2025-10-22 | Giorgos Maravelias | Set Loki to single-tenant (`auth_enabled: false`) to fix Grafana 401; updated troubleshooting |
|     1.10 | 2025-12-02 | Codex Agent        | Wired Keycloak to Postgres for persistent auth data; updated README |
|     1.11 | 2025-12-02 | Codex Agent        | Added stack update script documentation and usage details |
|     1.12 | 2025-12-09 | Codex Agent        | Documented custom Keycloak login theme and how to modify it |
|     1.13 | 2025-12-09 | Codex Agent        | Added bespoke Keycloak login/template overrides and logo guidance |
|     1.14 | 2026-01-07 | Codex Agent        | Updated service versions to match compose (Postgres 18, pgAdmin 9.11, Keycloak 26.5.0, SonarQube 26.1, Prometheus 3.9, Loki 3.6, Grafana 12.3, Nginx 1.29) |

## Folder Structure
```
local-dev/
├── docker-compose.yml              # Orchestrates all local services
├── nginx/
│   └── html/
│       └── index.html              # Static welcome page served by Nginx
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasource.yml      # Pre-provisioned Prometheus and Loki datasources
├── keycloak/
│   ├── MyOperations-realm.json     # Realm, roles, users, and clients for MyOperations
│   └── themes/
│       └── myoperations/           # Custom Keycloak login theme (CSS + messages)
├── loki/
│   └── config.yml                  # Loki configuration for single-process mode
├── pgadmin/
│   └── servers.json                # Preconfigured server connection to Postgres
├── postgres/
│   └── init/
│       ├── 01_pgvector.sql         # Initializes pgvector extension
│       └── 20-keycloak.sql         # Creates Keycloak database/user for Postgres persistence
├── prometheus/
│   └── prometheus.yml              # Prometheus scrape configuration (self + local app)
├── ansible/
│   ├── inventory.ini               # Ansible inventory for remote VM
│   └── site.yml                    # Ansible playbook to deploy local stack
├── scripts/
│   ├── deploy-to-vm.sh             # Install Docker and deploy stack on a VM
│   ├── cleanup.sh                  # Cleanup helper (local or VM modes)
│   └── update-stack.sh             # Git pull + restart or full reset of the stack
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
  docker compose -f local-dev/docker-compose.yml up -d
  ```
- Stop and remove containers (keep volumes):
  ```bash
  docker compose -f local-dev/docker-compose.yml down
  ```
- Recreate from scratch (removes named volumes; destructive):
  ```bash
  docker compose -f local-dev/docker-compose.yml down
  docker volume rm myoperations-local-stack_postgres-data myoperations-local-stack_sonar-db-data myoperations-local-stack_sonar-data myoperations-local-stack_sonar-extensions myoperations-local-stack_prometheus-data myoperations-local-stack_grafana-storage myoperations-local-stack_loki-data myoperations-local-stack_pgadmin-data 2>/dev/null || true
  docker compose -f local-dev/docker-compose.yml up -d
  ```
- Status and logs:
  ```bash
  docker compose -f local-dev/docker-compose.yml ps
  docker compose -f local-dev/docker-compose.yml logs -f
  docker compose -f local-dev/docker-compose.yml logs -f <service>
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

## Stack Update Script
Automate the "pull latest + restart stack" workflow via:
```bash
bash local-dev/scripts/update-stack.sh
```
The script:
- Fetches and pulls the latest commits from `origin` (respecting your current branch unless overridden).
- Stops the local stack (`docker compose down`).
- Prompts whether to perform a full Docker reset (remove named volumes + `myoperations-network`) or simply restart.
- Pulls images and brings the stack back up (`docker compose up -d`).

Flags:
- `--full-reset` – skip the prompt and wipe volumes/network before recreating (destructive).
- `--restart-only` – skip the prompt and keep existing data (default).
- `--branch <name>` / `--remote <name>` – override the Git target.
- `--yes` – run non-interactively (defaults to restart-only unless explicitly told otherwise).

 
