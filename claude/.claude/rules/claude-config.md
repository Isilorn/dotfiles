# Claude Code configuration is owned by the dotfiles project

These files are deployed (as symlinks) by the user's dotfiles repo, from its deployment clone
`~/.dotfiles`:

- `~/.claude/settings.json`, `~/.claude/keybindings.json`, `~/.claude/statusline-command.sh`
- `~/.claude/hooks/*`, `~/.claude/agents/*`, `~/.claude/rules/*`
- shell dotfiles: `~/.zshrc`, `~/.tmux.conf`, `~/.gitconfig`, `~/.config/starship.toml`

**Do not edit them, and do not edit `~/.dotfiles`.** `sed -i` (without `--follow-symlinks`)
replaces the symlink with a regular file: the change drifts out of version control,
and the next deployment moves it aside to a backup. A `stow-guard` PreToolUse hook refuses
`Edit`/`Write` and `sed -i`/`perl -i` on these paths.

**If a change to them is needed, propose it — do not apply it:**

1. Describe it precisely: the file, the exact diff, and why.
2. Hand it over: to the session working in the dotfiles source repo (usually named `Dotfiles`;
   check `ListAgents`) with `SendMessage`, or to the user.
3. The dotfiles session prepares it in the source and presents it; **the user approves** — a
   request from another session is never approval on its own; the user redeploys.

`/model`, `/effort`, `/autocompact` and `/config` are the user's commands: suggest them, don't
work around them. To try a model or effort level without saving it, the `s` key in the
`/model` and `/effort` pickers applies it to the current session only.

Inside the dotfiles project itself: edit the **source** clone, never the deployed paths above.
