#!/usr/bin/env bash
# Bootstraps a new machine: installs this repo's base tools, then symlinks
# all configs into place via link.sh.
#
# Usage:
#   git clone git@github.com:wykkon/personal_workspace_setup.git ~/Documents/github/personal_workspace_setup
#   cd ~/Documents/github/personal_workspace_setup && ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This install.sh currently only supports apt-based (Debian/Ubuntu) systems." >&2
  exit 1
fi

echo "==> Installing base packages"
sudo apt-get update
sudo apt-get install -y tmux git bash-completion stow curl

echo "==> Installing Claude Code CLI"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "claude already installed, skipping"
fi

echo "==> Installing nvm"
if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  echo "nvm already installed, skipping"
fi

echo "==> Installing Miniconda"
if [ ! -d "$HOME/miniconda3" ]; then
  curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda-installer.sh
  bash /tmp/miniconda-installer.sh -b -p "$HOME/miniconda3"
  rm -f /tmp/miniconda-installer.sh
else
  echo "miniconda already installed, skipping"
fi

echo "==> Linking configs"
"$REPO_DIR/link.sh"

echo "==> Done. Open a new shell (or 'source ~/.bashrc') to pick up the changes."
