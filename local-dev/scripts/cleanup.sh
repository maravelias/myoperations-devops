#!/usr/bin/env bash
set -euo pipefail

# cleanup.sh
# Safely remove the MyOperations local stack, with options for local or VM (systemd-managed) deployments.
# Default is interactive; pass --yes for non-interactive.
#
# Examples:
#   # Local workstation: stop containers only
#   bash local-dev/scripts/cleanup.sh --local
#
#   # Local workstation: full reset (remove volumes + network)
#   bash local-dev/scripts/cleanup.sh --local --remove-volumes --remove-network --yes
#
#   # VM: remove systemd unit, stop stack, remove volumes/network, delete repo dir
#   sudo bash local-dev/scripts/cleanup.sh --vm --repo-dir /opt/myoperations-devops \
#        --remove-volumes --remove-network --purge-repo --yes

MODE=""              # "local" or "vm"; if empty, auto-detect
REPO_DIR=""          # Repo path; defaults differ per mode
REMOVE_VOLUMES=0
REMOVE_NETWORK=0
PURGE_REPO=0
ASSUME_YES=0

PROJECT_NAME="myoperations-local-stack"
NETWORK_NAME="myoperations-network"
SERVICE_NAME="myoperations-local-stack.service"

VOLUMES=(
  "${PROJECT_NAME}_postgres-data"
  "${PROJECT_NAME}_sonar-db-data"
  "${PROJECT_NAME}_sonar-data"
  "${PROJECT_NAME}_sonar-extensions"
  "${PROJECT_NAME}_prometheus-data"
  "${PROJECT_NAME}_grafana-storage"
  "${PROJECT_NAME}_loki-data"
  "${PROJECT_NAME}_pgadmin-data"
)

info() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*"; }
err()  { echo -e "[ERR ] $*" >&2; }

confirm() {
  local prompt="$1"; shift || true
  if [[ ${ASSUME_YES} -eq 1 ]]; then
    return 0
  fi
  read -r -p "${prompt} [y/N]: " ans || true
  [[ "${ans:-}" == "y" || "${ans:-}" == "Y" ]]
}

usage() {
  cat <<EOF
Usage: bash local-dev/scripts/cleanup.sh [--local|--vm] [options]

Modes (choose one; auto-detect if omitted):
  --local                 Cleanup on local workstation (Docker Compose only)
  --vm                    Cleanup on VM with systemd-managed service

Options:
  --repo-dir PATH         Repo root path (defaults: local=script/../.., vm=/opt/myoperations-devops)
  --remove-volumes        Remove named volumes (destructive)
  --remove-network        Remove dedicated Docker network (${NETWORK_NAME})
  --purge-repo            Remove repo directory (VM mode)
  --yes                   Assume "yes" for prompts (non-interactive)
  -h, --help              Show this help

Notes:
  - VM mode may require root privileges. Use sudo.
  - Volume deletion resets service data (Postgres, SonarQube, Grafana, Loki, pgAdmin).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) MODE="local"; shift;;
    --vm) MODE="vm"; shift;;
    --repo-dir) REPO_DIR="$2"; shift 2;;
    --remove-volumes) REMOVE_VOLUMES=1; shift;;
    --remove-network) REMOVE_NETWORK=1; shift;;
    --purge-repo) PURGE_REPO=1; shift;;
    --yes) ASSUME_YES=1; shift;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 1;;
  esac
done

# Auto-detect mode if not provided
if [[ -z "${MODE}" ]]; then
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "^${SERVICE_NAME}\\."; then
    MODE="vm"
    info "Auto-detected VM mode (found ${SERVICE_NAME})."
  else
    MODE="local"
    info "Defaulting to local mode."
  fi
fi

# Resolve default repo dir
if [[ -z "${REPO_DIR}" ]]; then
  if [[ "${MODE}" == "local" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  else
    REPO_DIR="/opt/myoperations-devops"
  fi
fi

COMPOSE_FILE="${REPO_DIR}/local-dev/docker-compose.yml"

info "Mode: ${MODE}"
info "Repo dir: ${REPO_DIR}"
info "Compose file: ${COMPOSE_FILE}"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  warn "Compose file not found at ${COMPOSE_FILE}. Some steps may be skipped."
fi

if [[ "${MODE}" == "vm" ]]; then
  if [[ ${EUID} -ne 0 ]]; then
    err "VM mode may require root privileges. Re-run with sudo."
    exit 1
  fi
  info "Stopping and removing systemd service: ${SERVICE_NAME}"
  systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
  systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
  if [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]]; then
    rm -f "/etc/systemd/system/${SERVICE_NAME}"
    systemctl daemon-reload
    systemctl reset-failed || true
  fi
fi

# Compose down
if [[ -f "${COMPOSE_FILE}" ]]; then
  info "Bringing down stack via docker compose"
  docker compose -f "${COMPOSE_FILE}" down || true
fi

# Remove volumes
if [[ ${REMOVE_VOLUMES} -eq 1 ]]; then
  if confirm "Remove named volumes (destructive)?"; then
    info "Removing volumes"
    for v in "${VOLUMES[@]}"; do
      docker volume rm "$v" 2>/dev/null || true
    done
  else
    info "Skipping volume removal"
  fi
fi

# Remove network
if [[ ${REMOVE_NETWORK} -eq 1 ]]; then
  if confirm "Remove network ${NETWORK_NAME}?"; then
    info "Removing network ${NETWORK_NAME}"
    docker network rm "${NETWORK_NAME}" 2>/dev/null || true
  else
    info "Skipping network removal"
  fi
fi

# Purge repo directory (VM mode only)
if [[ "${MODE}" == "vm" && ${PURGE_REPO} -eq 1 ]]; then
  if [[ -d "${REPO_DIR}" ]]; then
    if confirm "Purge repo directory ${REPO_DIR}?"; then
      info "Removing ${REPO_DIR}"
      rm -rf "${REPO_DIR}"
    else
      info "Skipping repo purge"
    fi
  fi
fi

info "Cleanup completed."
