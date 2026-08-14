# Emacs configuration

Fork of [roife/.emacs.d](https://github.com/roife/.emacs.d) with extra local
modules. Package manager is [straight.el](https://github.com/radian-software/straight.el);
runtime files go through [no-littering](https://github.com/emacscollective/no-littering).

Requires **Emacs 29.1+** (native compilation assumed on Emacs 31). `early-init.el`
speeds startup (GC, `eln-cache` under `var/`, frame geometry 120×50).

## Directory layout

| Path | Role | Git |
|------|------|-----|
| `early-init.el` `init.el` `core/` | Config source; load order is `+init-files` in `init.el` | tracked |
| `private.el.example` | Template for machine-local identity | tracked |
| `private.el` | Name, email, Reddit user, magh clone path | ignored |
| `scripts/` | Elfeed / Gnus / telega helpers | tracked |
| `tempel-templates` | Tempel snippets (LaTeX/Org-oriented) | tracked |
| `mermaid-config-emacs.json` | Mermaid CLI config for Org Babel (`ob-mermaid`) | tracked |
| `straight/versions/default.el` | straight pinfile | tracked (rest of `straight/` ignored) |
| `straight/` | Package clones and builds | ignored |
| `var/` | Runtime state, caches, DBs, native modules | ignored |
| `etc/` | Machine-local state (`custom.el`, Gnus newsrc, …) | ignored |
| `tree-sitter` → `var/treesit` | Grammar dylibs (Emacs default install path) | ignored |
| `.grok/` `dev-docs/` `AGENTS.md` | Local agent/docs workspace | ignored |

**Policy:** do not write caches or DB state at config root. Prefer
`no-littering-expand-var-file-name` / `…-etc-file-name`. External data stays
in system locations (mail under `~/.local/share/mail/`, Rime under
`~/Library/Rime/` if you enable IME).

## Module load order

Source of truth: `+init-files` in `init.el` (keep this table in sync when
you add or comment a file).

| `core/` file | Loaded | Role |
|--------------|--------|------|
| `init-util` | yes | `add-hook!` / `defadvice!` |
| `init-straight` | yes | straight + use-package |
| `init-basic` | yes | no-littering, files, secrets, defaults |
| `init-ui` | yes | fonts, doom-gruvbox, ligature, scrollview |
| `init-xterm` | yes | TTY glyphs, Kitty graphics/keyboard |
| `init-ghostel` | yes | Ghostty VT terminal (`C-x m`) |
| `init-mac` | Darwin only | Super keys, emt, osx-dictionary, appearance |
| `init-completion` | yes | Vertico (buffer UI), orderless, Consult, Corfu, Embark, Tempel |
| `init-tools` | yes | avy, vundo, reader, eww, … |
| `init-highlight` | yes | hl-line, rainbow, symbol-overlay, … |
| `init-edit` | yes | puni, jinx, apheleia, expreg, … |
| `init-window` | yes | ace-window, winner, popper, zoom |
| `init-dired` | yes | dired, `fd-dired` |
| `init-shell` | yes | Eshell (`C-\``) + Ghostel project toggle |
| `init-prog` | yes | Eglot, flymake, citre, minuet, language modes |
| `init-scheme` | yes | Geiser (Racket SICP, optional MIT Scheme) |
| `init-writing` | yes | Markdown, Typst, AUCTeX, md-babel |
| `init-org` | yes | Org, ob-mermaid, org-appear, org-modern |
| `init-vcs` | yes | Magit, forge, magh (`gh`), difftastic |
| `init-ibuffer` | yes | ibuffer + project groups |
| `init-ime` | **commented out** | librime / rimel / sis |
| `init-modal` | **commented out** | Meow |
| `init-modeline` | yes | custom mode-line, breadcrumb, tab-bar |
| `init-ai` | yes | gptel (DeepSeek), gptel-agent, Codex IDE |
| `init-agent-shell` | yes | ACP: Grok Build, Claude Code, Pi |
| `init-social` | yes | telega (unread summaries via Grok CLI), chirp |
| `init-gnus` | yes | Gmail Maildir (isync) + SMTP |
| `init-elfeed` | yes | RSS; local HN/Reddit atoms via `scripts/` |
| `init-media` | **commented out** | EMMS |
| `init-test` | yes | rust-analyzer xtask helper |
| `init-keybinding` | **not in `+init-files`** | Super keys (duplicate of `init-mac`) + CJK punctuation translation |

## Fonts

Set in `init-ui.el` (`+setup-fonts`). README previously listed Sarasa Gothic as
the default face; the running config is:

| Face / charset | Family |
|----------------|--------|
| `default` / `fixed-pitch` | **TX-02** (14pt macOS, 26pt elsewhere) |
| `variable-pitch` | **Sarasa UI SC** |
| Han / CJK | **LXGW WenKai Mono** |
| Emoji | **Apple Color Emoji** (macOS) or **Noto Color Emoji** |

Install those families or change `+setup-fonts`.

## Prerequisites

Always useful:

- `rg`, `fd`
- `enchant` + `pkgconf` (jinx native module; `brew install enchant pkgconf`)
- `universal-ctags` (citre)
- `difft` (magit-difftastic)
- `gh` (magh.el)

By feature (skip what you do not use):

| Feature | Tools |
|---------|--------|
| Mail (Gnus) | `isync`/`mbsync`, `~/.config/isyncrc`, Maildir `~/.local/share/mail/gmail/` |
| Spell | jinx → enchant (AppleSpell on macOS) |
| Org diagrams | Node `mmdc` (`@mermaid-js/mermaid-cli`); uses `mermaid-config-emacs.json` |
| TeX preview | `dvisvgm` (Org latex preview) |
| Scheme | Racket + `raco pkg install sicp`; optional `mit-scheme` |
| Telegram | TDLib (`M-x +telega-install-tdlib` / `scripts/install-telega-tdlib`) |
| Grok (agent-shell + telega summaries) | `~/.grok/bin/grok` and `grok login` |
| Claude in agent-shell | `npm i -g @agentclientprotocol/claude-agent-acp` and `claude login` |
| Pi in agent-shell | `pi` + `pi-acp` (Homebrew paths in `init-agent-shell.el`) |
| Ghostel | native sidecar under `var/ghostel/` (auto-download on first `M-x ghostel`) |
| IME (`init-ime`) | `librime` — **not loaded** unless you uncomment `init-ime` |
| Media (`init-media`) | `mpv`, `ffmpeg`, `exiftool` — **not loaded** unless you uncomment `init-media` |

agent-shell keys (see comments in `core/init-agent-shell.el`): `C-c C-g` start/reuse
(picker on a **new** shell: Grok / Claude / Pi), `C-u C-c C-g` force new,
`C-c C-;` compose. Grok is preselected, not exclusive.

## Credentials

Copy `private.el.example` to `private.el` (gitignored; loaded from `init.el`)
and set `user-full-name`, `user-mail-address`, optionally
`+reddit-private-rss-user` and `+magh-git-repo`. Mail and Reddit private RSS
do not work until that file exists.

`auth-source` reads `~/.authinfo` and/or `~/.authinfo.gpg` (never commit these;
`.gitignore` already excludes them).

| Secret | Used by |
|--------|---------|
| DeepSeek API (`api.deepseek.com` / `apikey`) | gptel, gptel-quick, minuet, Elfeed HN LLM |
| Gmail app password (`smtp.gmail.com`, IMAP via isync) | Gnus SMTP; `mbsync` |
| GitHub token | forge / ghub |
| `reddit-private-rss` / port `rss` | Elfeed private r/emacs atom (`scripts/reddit-elfeed.py`) |

Grok / Claude / Pi / Telegram sessions use their own CLI logins, not authinfo.

Gnus is **mail only** (local Gmail Maildir). News, blogs, and HN live in Elfeed.
There is no Emacs China NNTP method in this tree.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/update-elfeed-feeds` | Refresh `var/rss/*.atom` (HN LLM gated by `ELFEED_HN_LLM`) |
| `scripts/hn-elfeed.py` | Hacker News local Atom |
| `scripts/reddit-elfeed.py` | Private Reddit Atom |
| `scripts/update-gnus-sources` | `mbsync --all` before Gnus |
| `scripts/install-telega-tdlib` | Build telega’s TDLib under `~/.local` (macOS) |
