#!/usr/bin/env bash
set -euo pipefail

# update-stack.sh
# Pull latest changes from GitHub, stop the local stack, and either:
#   (a) restart it with existing volumes, or
#   (b) perform a full Docker reset (remove volumes/network) before recreating.

ASSUME_YES=0
FULL_RESET=0
FULL_RESET_EXPLICIT=0
REMOTE="origin"
BRANCH=""
REPO_DIR=""

PROJECT_NAME="myoperations-local-stack"
NETWORK_NAME="myoperations-network"
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

usage() {
  cat <<'EOF'
Usage: bash local-dev/scripts/update-stack.sh [options]

Options:
  --repo-dir PATH     Repository root (default: script/../..)
  --branch BRANCH     Override Git branch to pull (default: current branch/upstream)
  --remote NAME       Git remote to pull from (default: origin)
  --full-reset        Remove stack volumes + network before recreating (destructive)
  --restart-only      Skip destructive reset (default)
  --yes               Assume "yes" for prompts (non-interactive)
  -h, --help          Show this help

Behavior:
  1. Fetch + pull latest changes from the configured Git remote/branch.
  2. Stop the Docker Compose stack defined in local-dev/docker-compose.yml.
  3. Optionally remove the stack's named volumes and dedicated network.
  4. Pull images and start the stack again with docker compose up -d.
EOF
}

confirm() {
  local prompt="$1"; shift || true
  if [[ ${ASSUME_YES} -eq 1 ]]; then
    return 0
  fi
  read -r -p "${prompt} [y/N]: " ans || true
  [[ "${ans:-}" == "y" || "${ans:-}" == "Y" ]]
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command '$1' not found in PATH."
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir) REPO_DIR="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --remote) REMOTE="$2"; shift 2;;
    --full-reset) FULL_RESET=1; FULL_RESET_EXPLICIT=1; shift;;
    --restart-only) FULL_RESET=0; FULL_RESET_EXPLICIT=1; shift;;
    --yes) ASSUME_YES=1; shift;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 1;;
  esac
done

# Default repo dir relative to this script
if [[ -z "${REPO_DIR}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

COMPOSE_FILE="${REPO_DIR}/local-dev/docker-compose.yml"

require_cmd git
require_cmd docker

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  err "Directory ${REPO_DIR} does not appear to be a Git repository."
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  err "Compose file not found at ${COMPOSE_FILE}."
  exit 1
fi

if [[ -z "${BRANCH}" ]]; then
  if BRANCH=$(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null); then
    :
  else
    warn "Unable to detect current branch; Git will use configured upstream."
    BRANCH=""
  fi
fi

if [[ ${FULL_RESET_EXPLICIT} -eq 0 && ${ASSUME_YES} -eq 0 ]]; then
  if confirm "Perform full Docker reset (remove named volumes + network)?"; then
    FULL_RESET=1
  fi
elif [[ ${FULL_RESET_EXPLICIT} -eq 0 && ${ASSUME_YES} -eq 1 ]]; then
  info "No reset mode specified; defaulting to restart-only in non-interactive mode."
fi

info "Repository: ${REPO_DIR}"
info "Git remote: ${REMOTE}"
info "Branch: ${BRANCH:-<upstream>}"
info "Compose file: ${COMPOSE_FILE}"
info "Reset mode: $([[ ${FULL_RESET} -eq 1 ]] && echo 'full reset' || echo 'restart only')"

info "Fetching latest changes from ${REMOTE}"
git -C "${REPO_DIR}" fetch "${REMOTE}" --prune

info "Pulling latest commits"
if [[ -n "${BRANCH}" ]]; then
  git -C "${REPO_DIR}" pull --ff-only "${REMOTE}" "${BRANCH}"
else
  git -C "${REPO_DIR}" pull --ff-only
fi

info "Stopping Docker Compose stack"
docker compose -f "${COMPOSE_FILE}" down

if [[ ${FULL_RESET} -eq 1 ]]; then
  info "Removing named volumes (destructive)"
  for v in "${VOLUMES[@]}"; do
    docker volume rm "${v}" 2>/dev/null || true
  done

  info "Removing network ${NETWORK_NAME}"
  docker network rm "${NETWORK_NAME}" 2>/dev/null || true
fi

info "Pulling container images"
docker compose -f "${COMPOSE_FILE}" pull

info "Starting Docker Compose stack"
docker compose -f "${COMPOSE_FILE}" up -d

info "Update complete."
