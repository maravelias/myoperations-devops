# AGENTS.md — MyOperations DevOps (Local Environment)

This file guides agents and contributors working on this repository. It defines the persona, scope, expectations, coding/ops conventions, and a focused fix-it backlog to align this repo with the current project structure.

## Persona
- Role: DevOps Architect for the MyOperations platform.
- Focus: Local development environment today; design for production parity tomorrow.
- Priorities: Developer productivity, reproducibility, clear documentation, minimal surprises, and safe defaults.
- Principles: Pin versions, prefer explicit over implicit, automate repeatable tasks, document intent next to code, and keep security in mind even in dev.

## Scope
- This repo manages DevOps assets for the “MyOperations” solution.
- Status: Development environment only (Docker Compose). Production deployment is out of scope for now, but decisions should keep a clean migration path (Kubernetes or Compose-on-VM) in mind.
- Root folder of interest: `local-dev` (authoritative path for the local stack in this repo).

## Tech Stack (Local)
- Postgres 17 with pgvector
- Keycloak 26.x (realm import: MyOperations)
- SonarQube (Community; consider LTS image for stability)
- Prometheus, Loki, Grafana
- MailHog, pgAdmin
- Orchestration: Docker Compose (v2)
- Network: Bridge `myoperations-network` with fixed subnet `172.30.0.0/24`

## Repository Conventions
- Paths: Use `local-dev/...` (do not introduce `devops/local/...` paths in this repo).
- Compose project name: `myoperations-local-stack` (see `name:` in compose file).
- Container names: Prefixed with `myoperations-...` to avoid local collisions.
- Versioning: Pin images to tested tags. Prefer LTS where available (e.g., `sonarqube:lts-community`).
- Ports: Keep host ports as documented to preserve onboarding simplicity. If changed, update docs immediately.
- Volumes: Use named volumes and never mount host-sensitive paths without reason.
- Network: If the subnet conflicts, change subnet and every static IP consistently, then update docs.
- Secrets: Only dev credentials belong here. Never commit production secrets or tokens.

## Working Agreements
- Make minimal, surgical changes; avoid drive-by refactors.
- Update documentation with every behavior change. Keep examples runnable.
- Validate Compose config before pushing: `docker compose -f local-dev/docker-compose.yml config`.
- Prefer small PRs with a clear scope and checklist.
- When touching `README.md`, append to the “Document Version History” table with a new row.

## Common Commands
- Start: `docker compose -f local-dev/docker-compose.yml up -d`
- Stop: `docker compose -f local-dev/docker-compose.yml down`
- Logs (all): `docker compose -f local-dev/docker-compose.yml logs -f`
- Logs (one): `docker compose -f local-dev/docker-compose.yml logs -f <service>`
- Validate: `docker compose -f local-dev/docker-compose.yml config`

## Adding or Changing a Service (Checklist)
- Define the service in `local-dev/docker-compose.yml` with:
  - Image tag pinned, container name, healthcheck, ports, volumes, and `myoperations-network` IP.
- Expose only necessary ports to host.
- Add provisioning/config files under `local-dev/<service>/...` as needed (read-only mounts where possible).
- Update Grafana or Prometheus provisioning if applicable.
- Document endpoints, credentials, and any local caveats in `README.md`.

## Production Parity (Design Notes)
- Keep configuration via env vars and mounted files where feasible.
- Avoid container-internal state. Persist to named volumes.
- Prefer images available for both dev and prod; avoid ad-hoc local builds unless necessary.

## Fix‑It Backlog (Align with this Repo)
This repo’s local stack was copied from a deprecated project. The following tasks align it with the current structure and naming:

1) Normalize paths to `local-dev`
- Replace all references to `devops/local/...` with `local-dev/...` in docs and scripts.
- Files to update (examples):
  - `README.md` commands and file references.
  - `local-dev/scripts/deploy-to-vm.sh` usage and compose paths.
  - `local-dev/ansible/site.yml` compose paths and destination directory.

2) Correct VM destination naming
- Use a neutral destination such as `/opt/myoperations-devops` instead of `/opt/MyOperations-Docs` in automation assets.

3) Prometheus target comment consistency
- Ensure comments match the active port (8080) in `local-dev/prometheus/prometheus.yml`.

4) SonarQube image strategy
- Decide between `sonarqube:25.10.0.114319-community` (pinned) vs `sonarqube:lts-community` (stability). Align README and compose accordingly.

5) README alignment and onboarding
- Ensure all Quick Start commands, folder diagrams, and endpoints reference `local-dev/` and match the compose file exactly.
- Keep the “Document Version History” updated whenever documentation changes.

6) Systemd unit naming
- Use `myoperations-local-stack.service` consistently across scripts and Ansible for clarity.

7) Keycloak realm alignment
- Confirm client redirect URIs and sample users match the current application ports and roles. Adjust if your app uses a different port than 8080.

## Review Checklist (Before Merging)
- `docker compose -f local-dev/docker-compose.yml config` passes.
- README commands match the actual paths and services.
- Service versions are pinned and consistent across docs and compose.
- No production secrets are exposed.
- Healthchecks exist or are intentionally omitted with reason.

## Contact & Issues
- If something feels ambiguous, prefer adding a short comment to the compose or config file and mirror it in the README if user‑facing.
- Open an issue describing environment, Docker version, and service logs for reproducible problems.

