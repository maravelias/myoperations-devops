#!/usr/bin/env bash
set -euo pipefail

# deploy-to-vm.sh
# Installs Docker Engine + Compose plugin, applies SonarQube sysctl, and brings up the local stack.
# Optionally installs a systemd unit to auto-start the stack on boot.
#
# Usage examples (run on the VM over SSH):
#   sudo bash local-dev/scripts/deploy-to-vm.sh
#   sudo bash local-dev/scripts/deploy-to-vm.sh --with-systemd
#   sudo bash local-dev/scripts/deploy-to-vm.sh --repo-dir /opt/myoperations-devops --user ubuntu --with-systemd

WITH_SYSTEMD=0
REPO_DIR=""
TARGET_USER="${SUDO_USER:-${USER:-root}}"

usage() {
  cat <<EOF
Usage: sudo bash local-dev/scripts/deploy-to-vm.sh [options]

Options:
  --repo-dir PATH     Path to repo root containing local-dev/docker-compose.yml
  --user NAME         User to add to docker group (default: ${TARGET_USER})
  --with-systemd      Install a systemd unit to auto-start the stack on boot
  -h, --help          Show this help

Notes:
  - Run as root (via sudo). Installs Docker Engine + Compose plugin from Docker's repo.
  - Sets vm.max_map_count=262144 for SonarQube.
  - Brings up the stack using docker compose.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir)
      REPO_DIR="$2"; shift 2;;
    --user)
      TARGET_USER="$2"; shift 2;;
    --with-systemd)
      WITH_SYSTEMD=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root (use sudo)." >&2
  exit 1
fi

# Resolve repo dir if not provided: assume script lives in repo/local-dev/scripts
if [[ -z "${REPO_DIR}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

COMPOSE_FILE="${REPO_DIR}/local-dev/docker-compose.yml"
if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Cannot find docker-compose.yml at: ${COMPOSE_FILE}" >&2
  exit 1
fi

echo "==> Using repo dir: ${REPO_DIR}"
echo "==> Target user for docker group: ${TARGET_USER}"

install_prereqs() {
  echo "==> Installing prerequisites (ca-certificates, curl, gnupg, lsb-release)"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "==> Docker and Compose plugin already installed"
    systemctl enable --now docker || true
    return
  fi

  echo "==> Installing Docker Engine and Compose plugin from Docker's APT repo"
  install_prereqs
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  . /etc/os-release
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

configure_sysctl() {
  echo "==> Applying SonarQube sysctl: vm.max_map_count=262144"
  SYSCTL_FILE=/etc/sysctl.d/99-sonarqube.conf
  echo 'vm.max_map_count=262144' > "${SYSCTL_FILE}"
  sysctl -p "${SYSCTL_FILE}" || true
}

add_user_to_docker_group() {
  if id -u "${TARGET_USER}" >/dev/null 2>&1; then
    echo "==> Adding ${TARGET_USER} to docker group"
    usermod -aG docker "${TARGET_USER}" || true
  else
    echo "==> User ${TARGET_USER} not found; skipping group modification" >&2
  fi
}

bring_up_stack() {
  echo "==> Bringing up stack via docker compose"
  (cd "${REPO_DIR}" && docker compose -f local-dev/docker-compose.yml up -d)
}

install_systemd_unit() {
  echo "==> Installing systemd unit: myoperations-local-stack.service"
  SERVICE_FILE=/etc/systemd/system/myoperations-local-stack.service
  cat > "${SERVICE_FILE}" <<UNIT
[Unit]
Description=MyOperations Local Stack (Docker Compose)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${REPO_DIR}
ExecStart=/usr/bin/docker compose -f local-dev/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f local-dev/docker-compose.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now myoperations-local-stack.service
}

install_docker
configure_sysctl
add_user_to_docker_group
bring_up_stack

if [[ "${WITH_SYSTEMD}" -eq 1 ]]; then
  install_systemd_unit
fi

echo "==> Done. Service endpoints:"
echo "  - SonarQube: http://$(hostname -I | awk '{print $1}'):9000"
echo "  - MailHog UI: http://$(hostname -I | awk '{print $1}'):8025 (SMTP: 1025)"
echo "  - Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "  - Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "  - Keycloak: http://$(hostname -I | awk '{print $1}'):5080"
echo "  - PGadmin: http://$(hostname -I | awk '{print $1}'):5050"
echo "  - Postgres: $(hostname -I | awk '{print $1}'):5432"
echo
echo "Note: If ${TARGET_USER} was just added to the docker group, re-login is required for non-root docker usage."
