# Emacs configuration

Fork of [roife/.emacs.d](https://github.com/roife/.emacs.d) with local modules
(agent-shell, elfeed, ghostel, scheme). Layout follows upstream + no-littering.

## Directory layout

| Path | Role | Git |
|------|------|-----|
| `early-init.el` `init.el` `core/` `scripts/` `tempel-templates` | Config source | tracked |
| `private.el.example` | Template for machine-local identity | tracked |
| `private.el` | Name, email, Reddit user, magh clone path | ignored |
| `straight/` | Package manager (optional `versions/default.el` pin) | ignored (versions may be tracked) |
| `var/` | Runtime state, caches, DBs (no-littering) | ignored |
| `etc/` | Machine-local package state (`custom.el`, …) | ignored |
| `tree-sitter` → `var/treesit` | Grammar dylibs (symlink for Emacs default install path) | ignored |
| `.grok/` `dev-docs/` `AGENTS.md` | Local agent/docs workspace | ignored |

**Policy:** do not write caches or DB state at config root. Prefer
`no-littering-expand-var-file-name` / `…-etc-file-name`. External data stays
in system locations (e.g. `~/Library/Rime/`).

**Local modules** (not in upstream): `init-agent-shell`, `init-elfeed`,
`init-ghostel`, `init-scheme`. Upstream `init-ime` / `init-modal` / `init-media`
exist but may be commented out in `init.el`.

## Prerequisites

- Font
  + `Apple Color Emoji` / `Noto Color Emoji`
  + `Sarasa Gothic`
- `rg`
- `fd`
- `enchant` (AppleSpell provider)
- `librime`
- `isync`
- `mpv`
- `ffmpeg`
- `exiftool`
- `universal-ctags`
- `difft`

## Credentials

Copy `private.el.example` to `private.el` (gitignored; loaded from `init.el`)
and set `user-full-name`, `user-mail-address`, optionally
`+reddit-private-rss-user` and `+magh-git-repo`. Mail and Reddit private RSS
do not work until that file exists.

- `~/.authinfo`
  + Deepseek API (for `gptel`)
- `~/.authinfo.gpg`
  + Gmail app password (for Gnus, mbsync, and SMTP, note: use imap.googlemail.com with TLS 1.2 for Gmail)
  + GitHub token (for `forge`)
  + `reddit-private-rss` (Elfeed private r/emacs atom)

Never commit `private.el`, `authinfo`, or `*.gpg`. `.gitignore` already excludes them.
