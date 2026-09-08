# dotfiles

Personal dotfiles for **Mac (arm64)** and **Bluemoon (Ubuntu 24.04)**, managed with [GNU Stow](https://www.gnu.org/software/stow/).

Stack: `zsh` · `zinit` · `git` + `delta` · `tmux` · `starship` · `wezterm`

## Structure

| Package | Symlink target | Machines |
|---|---|---|
| `git/` | `~/.gitconfig` | all |
| `zsh/` | `~/.zshrc` | all |
| `tmux/` | `~/.tmux.conf` | all |
| `starship/` | `~/.config/starship.toml` | all |
| `wezterm/` | `~/.config/wezterm/wezterm.lua` | macOS only |
| `claude/` | `~/.claude/{settings.json,keybindings.json,statusline-command.sh}` | all |

## Installation

### macOS (arm64)

1. Install [Homebrew](https://brew.sh) if not present:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install [Claude Code](https://claude.ai/code) if not present (not managed by `install.sh`):
   ```bash
   npm install -g @anthropic-ai/claude-code
   ```

3. Clone and run the install script:
   ```bash
   git clone https://github.com/Isilorn/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ./install.sh
   ```

4. Fill in your local git identity:
   ```bash
   vim ~/.gitconfig.local
   ```

5. Open a new shell — zsh is now the default shell.

### Ubuntu / Bluemoon

```bash
git clone https://github.com/Isilorn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
vim ~/.gitconfig.local
```

Open a new shell.

### Updating

To apply new configs on an already-configured machine:

```bash
cd ~/.dotfiles
git pull
./install.sh --no-packages   # restow only, no apt/brew reinstall
```

If new packages were added to `install.sh` since the last install, run without `--no-packages`:

```bash
./install.sh
```

### Script options

```bash
./install.sh --dry-run      # preview everything without modifying anything
./install.sh --rollback     # restore original files and remove symlinks
./install.sh --no-packages  # stow only, skip package installation
./install.sh --verify       # check the deployment for drift, change nothing
./install.sh --no-stow      # packages only, skip symlinking
```

### Checking for drift

The repo is the source of truth; the clone you deploy from is only a copy. Editing a
deployed file in place silently replaces its stow symlink with a real file, which cuts it
off from version control until the next `stow` overwrites it.

`./install.sh --verify` reports, without changing anything:

- packaged files that are no longer symlinks back into the repo (or point elsewhere);
- directories stow folded into a symlink, where anything written later lands in the repo;
- how far this clone is behind its upstream, and any uncommitted changes in it.

It exits non-zero when something needs attention, so it can be scripted or scheduled.

### Automatic backup

If files already exist (`~/.zshrc`, `~/.gitconfig`, etc.), `install.sh` moves them to `~/.dotfiles-backup/<timestamp>/` before stowing. Multiple installs each create their own timestamped entry.

`--rollback` automatically restores from the most recent backup.

## Local files (never committed)

### `~/.gitconfig.local`

Created automatically by `install.sh` as an empty scaffold. Contains everything machine- or identity-specific — never committed.

```ini
[user]
    name  = Your Name
    email = your@email.com

# GPG commit signing (optional)
# [user]
#     signingkey = ABCDEF1234567890
# [commit]
#     gpgsign = true

# Machine-specific aliases (optional)
# [alias]
#     work = "!cd ~/work && code ."
```

`~/.gitconfig` includes this file at the end via `[include]`, allowing it to override any global setting.

## Rebuilding a machine from scratch

Three separate mechanisms produce a working Claude Code setup, and only one of them reaches both
machines — this repo. The other two are referenced here rather than duplicated.

| Mechanism | Installs | Runs on |
|---|---|---|
| provisioning tooling | Claude Code itself, the managed blocks of `~/.claude/CLAUDE.md`, the toolbox skills | Linux box only |
| **this repo** | `settings.json`, keybindings, the status line, the context hook, the four agents | both |
| skill deployment | the generic skills, from a local repo with no remote | Linux box only |

### On the Linux box

`./install.sh` covers this repo; the other two mechanisms are driven from their own repos.

### On macOS

1. **Install Claude Code by hand** — the provisioning tooling does not run here.
2. **This repo:**
   ```bash
   git clone <this repo> ~/.dotfiles && cd ~/.dotfiles
   ./install.sh
   ./install.sh --verify
   ```
   Check that `~/.claude/` is still a **real directory** with per-file symlinks. `install.sh`
   passes `--no-folding` to stow precisely so it stays that way: stow replaces no existing
   directory, but it creates a *symlink* for any directory missing on the target side — and
   `~/.claude/` also holds `projects/`, `plugins/` and `skills/`, which must never be versioned.
3. **The generic skills** — copied across from the Linux box for now. This step is deliberately
   manual and deliberately temporary: their source repo has no remote.
4. **The `SessionStart` hook** needs nothing: it is guarded, and is a silent no-op when the
   script it points at is absent (see above).

### Check the shell environment before trusting a scan

Claude Code snapshots the interactive shell, so an agent's commands can silently run through
wrappers — some from this repo's own aliases, some from the tool. One line lists them:

```bash
for c in grep find jq cat sed awk ls; do type -a $c | head -1; done
```

Seeing a wrapper you thought you had removed does not mean the fix failed. Two things keep it
alive independently: the repo change is not deployed until `git pull` + `install.sh` run in the
deployment clone (`--verify` reports how far behind it is), and Claude Code snapshots the
interactive shell **at session start** — already-open sessions keep the old wrappers until they
are closed, however current the files on disk are. Fixing the source only ever protects the
*next* shell.

Only one class actually matters. A **filtering** wrapper (e.g. a `grep` that skips
gitignored files) makes a scan return a *wrong* answer in silence — so any claim that something
is **absent** must be re-run with the real binary (`/usr/bin/grep`) before it is reported. A
*decorating* wrapper corrupts a redirection but reveals itself at the next parse; a *faithful*
drop-in replacement costs nothing. Scripts are immune either way: aliases and shell functions do
not survive a fork, so `install.sh` and the hooks always get the real binaries.

### What must NOT be carried over

The toolbox skills and the toolbox block of `~/.claude/CLAUDE.md` describe a specific Linux
devbox: a shared Python environment under `/opt`, browser engines at a fixed path, `apt`, and a
doctor command that exists only there. **Those paths are the instruction, not an illustration.**
An agent reading them on macOS would run a command that does not exist and conclude the tooling
is broken, when it is merely *different* — and a skill that lies is worse than a skill that is
missing: absence makes you probe, a lie makes you act. If macOS ever becomes a real workstation,
the answer is a macOS variant owned by the repo that builds the devbox, not a copy of this one.

**Never copy the shared secrets file** onto another machine. The global instructions forbid it,
and needing a secret on a second machine is a separate decision, taken explicitly.

### Hooks referencing files this repo does not deploy

`settings.json` registers two hooks. `UserPromptSubmit` points at
`claude/.claude/hooks/context-alert.sh`, which this repo deploys, so it is always there.

`SessionStart` is different: it points at a script under `~/.claude/skills/`, which is placed
by a separate tool that only runs on the Linux box. On a freshly stowed machine that file does
not exist, and an unguarded command fails with exit 127 at every session start. The entry is
therefore wrapped:

```
sh -c '[ -x <path> ] && exec <path> || true'
```

Present, it runs and its exit code propagates; absent, the hook is silently a no-op. JSON has
no comments, so this note is the only place that explains the wrapper — do not "clean it up".

### `~/.claude/settings.local.json`

Machine-specific Claude Code overrides — never committed. The shared `settings.json` enables `bypassPermissions` globally; use this file to layer additional `additionalDirectories`, env vars or hooks that only apply to one machine:

```json
{
  "permissions": {
    "additionalDirectories": ["/opt/work-projects"]
  }
}
```

Project-level overrides go in `<project>/.claude/settings.local.json` (same merge rules).

### `~/.zshrc.local`

Sourced at the end of `.zshrc` if present. For anything that should not be shared across machines:

```zsh
# Example — environment variables, PATH additions, machine-specific aliases
export WORK_DIR=~/clients
export KUBECONFIG=~/.kube/config-prod
alias vpn='sudo openconnect vpn.example.com'
```

## Aliases

All aliases are conditional — they are only defined if the binary is present on the machine.

| Alias | Replaces / Command | Required package |
|---|---|---|
| `ls` / `ll` / `lt` | eza with options | `eza` |
| `cat` | `bat --style=plain --paging=never` | `bat` |
| `tree` | `tree -C` (colors) | `tree` |
| `top` | `btop` → `htop` → `top` (fallback) | `btop` or `htop` |
| `ncdu` | `ncdu --color dark -rr` | `ncdu` |
| `jq` | `jq -C` (colors) | `jq` |
| `duh` | `du -sh * \| sort -h` | — |
| `ports` | `ss -tlnp` (Linux) / `lsof -iTCP -sTCP:LISTEN` (macOS) | — |
| `myip` | `curl -s ifconfig.me` | `curl` |
| `python` | `python3` | if `python` absent |
| `pip` | `pip3` | if `pip` absent |

`btop` is not installed by `install.sh` — if present on the machine, the `top` alias will automatically use it.

## WezTerm and SSH

The WezTerm config (`wezterm/`) is only stowed on macOS. On remote machines, `.zshrc` automatically detects a WezTerm connection over SSH (via `$TERM=wezterm`) and sets `TERM_PROGRAM=WezTerm` and `COLORTERM=truecolor` without requiring any server-side configuration.
