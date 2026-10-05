# personal_workspace_setup

Personal workspace bootstrap: base tool installs + dotfiles, symlinked into
place with [GNU Stow](https://www.gnu.org/software/stow/).

## New machine

```bash
git clone git@github.com:wykkon/personal_workspace_setup.git ~/Documents/github/personal_workspace_setup
cd ~/Documents/github/personal_workspace_setup
./install.sh
```

`install.sh` installs the base tools (tmux, git, stow, Claude Code CLI, nvm,
Miniconda) and then runs `link.sh` for you. Currently targets apt-based
(Debian/Ubuntu) systems.

## Optional tools

```bash
./tools.sh              # install everything below
./tools.sh docker code  # install only the named tool(s)
```

Installs (idempotent, safe to re-run): Docker Engine + Compose plugin,
kubectl, Google Cloud CLI, VS Code, Slack, Postman, PyCharm, Chromium,
Spotify. Where a tool is available both as an official apt/deb package and
as an "App Center" (snap) build, the choice made here is:

| Tool     | Source                         | Why |
|----------|--------------------------------|-----|
| Docker   | Official apt repo              | Docker itself discourages the snap build (sandboxing issues) |
| kubectl  | Official apt repo (pkgs.k8s.io)| Standard method, versioned per k8s minor release |
| gcloud   | Official apt repo               | Standard Google-provided method |
| VS Code  | Official apt repo (Microsoft)   | Chosen over the snap build |
| Slack    | Official direct `.deb` download | No official apt repo; **not** the snap/App Center build |
| Postman  | Official tarball to `/opt`      | No official apt repo; chosen over the community snap |
| PyCharm  | App Center / snap               | Published by JetBrains themselves. JetBrains retired the separate Community/Professional snaps in favor of one unified `pycharm` snap — free core, Pro features via trial/subscription |
| Chromium | App Center / snap               | The standard path on Ubuntu today (apt just pulls the snap anyway) |
| Spotify  | App Center / snap               | Published by Spotify themselves |

See the comments at the top of `tools.sh` for the reasoning per tool, and
pass tool names as arguments to install a subset.

## Adding a new config

Each top-level folder is a Stow "package" whose internal path mirrors where
it belongs under `$HOME`. To add something new:

1. Create (or reuse) a package folder, e.g. `nvim/`.
2. Put the file at the path it should have under `$HOME`, e.g.
   `nvim/.config/nvim/init.vim`.
3. Run `./link.sh`.

No script changes needed — `link.sh` auto-discovers every top-level folder
and stows it. Existing real files/dirs at the target path are backed up to
`<path>.bak-<timestamp>` before linking, so re-running is always safe.

## Layout

```
bash/.bashrc                        -> ~/.bashrc
tmux/.tmux.conf                     -> ~/.tmux.conf
claude/.claude/skills/grill-me/     -> ~/.claude/skills/grill-me/
```

## Just re-linking (already bootstrapped)

```bash
./link.sh
```
