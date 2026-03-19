#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
#  install_tools.sh
#  Installs: Node.js (LTS), Docker, Docker Compose, Caddy
#  Tested on: Ubuntu 22.04 / 24.04 LTS
# ─────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}   $1"; }
error()   { echo -e "${RED}${BOLD}[ERR]${RESET}  $1" >&2; exit 1; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "Please run as root: sudo bash $0"
  fi
}

warn_if_direct_root_execution() {
  if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    warn "Detected direct root execution. No non-root user will be added to the docker group automatically."
    warn "Recommended: create a sudo user and run this script with: sudo bash ./install_tools.sh"
  fi
}

install_bootstrap_packages() {
  info "Installing bootstrap packages required by this script..."

  apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    python3

  success "Bootstrap packages installed."
}

# ─────────────────────────────────────────────
install_node() {
  info "Installing Node.js (LTS via NodeSource)..."

  apt-get remove -y nodejs npm 2>/dev/null || true

  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

  apt-get install -y nodejs

  success "Node.js $(node -v) and npm $(npm -v) installed."
}

# ─────────────────────────────────────────────
install_docker() {
  info "Installing Docker Engine + Docker Compose plugin..."

  apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable --now docker

  # Allow current non-root user (the one who called sudo) to run Docker
  ACTUAL_USER="${SUDO_USER:-}"
  if [[ -n "$ACTUAL_USER" ]]; then
    usermod -aG docker "$ACTUAL_USER"
    info "Added '$ACTUAL_USER' to the docker group. Log out and back in to apply."
  fi

  success "Docker $(docker version --format '{{.Server.Version}}') installed."
  success "Docker Compose $(docker compose version --short) installed."
}

# ─────────────────────────────────────────────
configure_docker_daemon() {
  info "Configuring Docker daemon (default bind to 127.0.0.1)..."

  local DAEMON_JSON="/etc/docker/daemon.json"

  mkdir -p /etc/docker

  if [[ -f "$DAEMON_JSON" ]]; then
    # File exists — merge the key in with Python's json module
    info "Existing $DAEMON_JSON found — merging 'ip' setting..."
    python3 - "$DAEMON_JSON" <<'EOF'
import sys, json

path = sys.argv[1]
with open(path, "r") as f:
    cfg = json.load(f)

cfg["ip"] = "127.0.0.1"

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
EOF
  else
    # File does not exist — create it from scratch
    cat > "$DAEMON_JSON" <<'EOF'
{
  "ip": "127.0.0.1"
}
EOF
  fi

  # Validate the JSON is well-formed before restarting
  python3 -c "import json; json.load(open('$DAEMON_JSON'))" \
    || error "$DAEMON_JSON is not valid JSON after edit — aborting."

  systemctl restart docker

  success "Docker daemon configured: unspecified port bindings will use 127.0.0.1."
  info "Verify with: cat /etc/docker/daemon.json and a test container started with -p."
}

# ─────────────────────────────────────────────
install_caddy() {
  info "Installing Caddy Server..."

  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

  apt-get update
  apt-get install -y caddy

  systemctl enable --now caddy

  success "Caddy $(caddy version) installed and running."
}

# ─────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}─────────────────────────────────────${RESET}"
  echo -e "${BOLD} Installation Summary${RESET}"
  echo -e "${BOLD}─────────────────────────────────────${RESET}"
  echo -e "  Node.js  →  $(node -v)"
  echo -e "  npm      →  $(npm -v)"
  echo -e "  Docker   →  $(docker version --format '{{.Server.Version}}')"
  echo -e "  Compose  →  $(docker compose version --short)"
  echo -e "  Caddy    →  $(caddy version)"
  echo -e "${BOLD}─────────────────────────────────────${RESET}"
  echo ""
}

print_post_install_notes() {
  if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    warn "Docker group was not assigned automatically because the script was not run via sudo from a non-root user."
    warn "If needed, add your admin user manually: usermod -aG docker <username>"
  fi
}

# ─────────────────────────────────────────────
main() {
  require_root
  warn_if_direct_root_execution

  info "Updating package index..."
  apt-get update -y
  install_bootstrap_packages

  install_node
  install_docker

  # Note: Docker daemon configuration is optional and may interfere with setup
  # configure_docker_daemon  

  install_caddy

  print_summary
  print_post_install_notes
  success "All tools installed successfully!"
}

main "$@"