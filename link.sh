#!/usr/bin/env bash
# Symlinks every package in this repo into $HOME via GNU Stow.
#
# To add something new: create a top-level folder (a "package") whose
# internal path mirrors where it belongs under $HOME, e.g.
#   nvim/.config/nvim/init.vim
# then re-run this script. No code changes needed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

if ! command -v stow >/dev/null 2>&1; then
  echo "GNU Stow not found. Run install.sh first (or: sudo apt-get install -y stow)." >&2
  exit 1
fi

PACKAGES=()
for dir in */; do
  name="${dir%/}"
  [ "$name" = ".git" ] && continue
  PACKAGES+=("$name")
done

# Stow refuses to touch a target that already exists and isn't one of its own
# symlinks. Back those up out of the way first so re-running this script is
# always safe, even on a machine with pre-existing dotfiles.
#
# Stow "folds" a directory into a single symlink when nothing else occupies
# that spot (e.g. ~/.claude/skills/grill-me -> repo/.../grill-me as one link,
# not one link per file inside it). So before checking a file's own target,
# walk its ancestors up to $HOME: if any of them is already a symlink, the
# whole subtree is already stowed and must NOT be inspected file-by-file --
# doing so would resolve through the symlink and "back up" (really: rename)
# the real file sitting in the repo.
is_under_symlink() {
  local path
  path="$(dirname "$1")"
  while [ "$path" != "$HOME" ] && [ "$path" != "/" ]; do
    [ -L "$path" ] && return 0
    path="$(dirname "$path")"
  done
  return 1
}

for pkg in "${PACKAGES[@]}"; do
  while IFS= read -r -d '' file; do
    rel="${file#"$pkg"/}"
    target="$HOME/$rel"
    is_under_symlink "$target" && continue
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      mkdir -p "$(dirname "$target.bak-$TIMESTAMP")"
      mv "$target" "$target.bak-$TIMESTAMP"
      echo "backed up $target -> $target.bak-$TIMESTAMP"
    fi
  done < <(find "$pkg" -type f -print0)
done

echo "Stowing packages: ${PACKAGES[*]}"
stow --restow --target "$HOME" --verbose=1 "${PACKAGES[@]}"
