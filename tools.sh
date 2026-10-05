#!/usr/bin/env bash
# Installs optional dev tools and GUI apps on top of install.sh's base
# bootstrap. Every step is idempotent (skips anything already installed), so
# this is safe to re-run, and can re-run after install.sh on any machine.
#
# Usage:
#   ./tools.sh              # install everything below
#   ./tools.sh docker code  # install only the named tool(s)
#
# Known tools: docker kubectl gcloud vscode slack postman pycharm chromium spotify
#
# Notes on choices made (see README for the apt-vs-"App Center"/snap
# reasoning per tool):
#   - docker       -> Docker's official apt repo; installs the Compose
#                     plugin too, invoked as `docker compose` (not the old
#                     standalone `docker-compose` binary).
#   - kubectl      -> Kubernetes' official apt repo (pkgs.k8s.io), pinned to
#                     a minor version that will need bumping over time.
#   - gcloud       -> Google Cloud's official apt repo.
#   - vscode       -> Microsoft's official apt repo.
#   - slack        -> Official direct .deb download (Slack has no apt repo
#                     and this intentionally skips the snap/App Center build).
#   - postman      -> Official tarball from Postman, installed to /opt.
#   - pycharm      -> App Center/snap (published by JetBrains themselves).
#                     JetBrains unified Community/Professional into one
#                     "pycharm" snap; this installs the free core, with Pro
#                     features available via trial/subscription in-app.
#   - chromium     -> App Center/snap (the standard path on Ubuntu today).
#   - spotify      -> App Center/snap (published by Spotify themselves).
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script currently only supports apt-based (Debian/Ubuntu) systems." >&2
  exit 1
fi

ensure_snapd() {
  if ! command -v snap >/dev/null 2>&1; then
    echo "==> Installing snapd"
    sudo apt-get update
    sudo apt-get install -y snapd
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "docker already installed, skipping"
    return
  fi
  echo "==> Installing Docker Engine + Compose plugin"
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  if ! getent group docker >/dev/null; then
    sudo groupadd docker
  fi
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group - log out/in (or 'newgrp docker') to use docker without sudo."
}

install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl already installed, skipping"
    return
  fi
  echo "==> Installing kubectl"
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

  sudo apt-get update
  sudo apt-get install -y kubectl
}

install_gcloud() {
  if command -v gcloud >/dev/null 2>&1; then
    echo "gcloud already installed, skipping"
    return
  fi
  echo "==> Installing Google Cloud CLI"
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y google-cloud-cli
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    echo "VS Code already installed, skipping"
    return
  fi
  echo "==> Installing Visual Studio Code"
  sudo apt-get update
  sudo apt-get install -y wget gpg
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg

  sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

  sudo apt-get update
  sudo apt-get install -y code
}

install_slack() {
  if command -v slack >/dev/null 2>&1; then
    echo "slack already installed, skipping"
    return
  fi
  echo "==> Installing Slack (.deb, official direct download, not the snap/App Center build)"
  local url
  url="$(curl -fsSL https://slack.com/downloads/linux \
    | grep -oE 'https://downloads\.slack-edge\.com/desktop-releases/linux/x64/[0-9.]+/slack-desktop-[0-9.]+-amd64\.deb' \
    | head -n1)"
  if [ -z "$url" ]; then
    echo "Could not auto-detect the latest Slack .deb URL from slack.com/downloads/linux." >&2
    echo "Download it manually and run: sudo apt-get install -y ./slack-desktop-*.deb" >&2
    return 1
  fi
  curl -fL -o /tmp/slack-desktop-amd64.deb "$url"
  sudo apt-get install -y /tmp/slack-desktop-amd64.deb
  rm -f /tmp/slack-desktop-amd64.deb
}

install_postman() {
  if command -v postman >/dev/null 2>&1; then
    echo "Postman already installed, skipping"
    return
  fi
  echo "==> Installing Postman (official tarball)"
  curl -fL -o /tmp/postman-linux-x64.tar.gz "https://dl.pstmn.io/download/latest/linux64"
  sudo rm -rf /opt/Postman
  sudo tar -xzf /tmp/postman-linux-x64.tar.gz -C /opt
  rm -f /tmp/postman-linux-x64.tar.gz
  sudo ln -sf /opt/Postman/Postman /usr/local/bin/postman

  sudo tee /usr/share/applications/postman.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Postman
Exec=/opt/Postman/Postman
Icon=postman
Terminal=false
Type=Application
Categories=Development;
EOF
}

install_pycharm() {
  ensure_snapd
  if snap list pycharm >/dev/null 2>&1; then
    echo "PyCharm already installed, skipping"
    return
  fi
  # JetBrains retired the separate pycharm-community/pycharm-professional
  # snaps in favor of one unified "pycharm" snap: free Community-equivalent
  # core, with Pro features available via a trial/subscription.
  echo "==> Installing PyCharm (snap, unified Community/Professional build)"
  sudo snap install pycharm --classic
}

install_chromium() {
  ensure_snapd
  if snap list chromium >/dev/null 2>&1; then
    echo "Chromium already installed, skipping"
    return
  fi
  echo "==> Installing Chromium (snap)"
  sudo snap install chromium
}

install_spotify() {
  ensure_snapd
  if snap list spotify >/dev/null 2>&1; then
    echo "Spotify already installed, skipping"
    return
  fi
  echo "==> Installing Spotify (snap)"
  sudo snap install spotify
}

ORDER=(docker kubectl gcloud vscode slack postman pycharm chromium spotify)
declare -A INSTALLERS=(
  [docker]=install_docker
  [kubectl]=install_kubectl
  [gcloud]=install_gcloud
  [vscode]=install_vscode
  [slack]=install_slack
  [postman]=install_postman
  [pycharm]=install_pycharm
  [chromium]=install_chromium
  [spotify]=install_spotify
)

main() {
  local targets=("$@")
  if [ ${#targets[@]} -eq 0 ]; then
    targets=("${ORDER[@]}")
  fi
  for name in "${targets[@]}"; do
    if [ -z "${INSTALLERS[$name]:-}" ]; then
      echo "Unknown tool: $name (known: ${ORDER[*]})" >&2
      exit 1
    fi
    "${INSTALLERS[$name]}"
  done
}

main "$@"
