## Prerequisite

- Font
  + `MonoLisaCode` / `MonoLisaText` (primary)
  + `LXGW WenKai Mono Screen` (CJK)
  + `Apple Color Emoji` / `Noto Color Emoji` (emoji)
- `rg`
- `fd`
- `aspell`
- `readability-cli`
- `difft` (difftastic, structural diff)

## Overview

This is a personal Emacs configuration (`~/.emacs.d`) using `straight.el` for package management and `use-package` for declarative package configuration. All init files use `lexical-binding: t`. Platform: macOS (Darwin) primary; Linux secondary.

## Startup flow

1. **`early-init.el`** — Runs before the UI initializes. Raises GC threshold to `most-positive-fixnum`, enables native-comp JIT, defers `package.el`, temporarily nulls `file-name-handler-alist` (restored on `emacs-startup-hook`), suppresses startup flashing (via `inhibit-redisplay`/`inhibit-message`, cleared on `window-setup-hook`), sets frame defaults in `default-frame-alist` (160×60, tab-bar on, no menu/tool/scroll bars, `ns-transparent-titlebar` on macOS), and silences `load-file` during init via temporary `define-advice`.
2. **`init.el`** — Defines `+init-files`, an ordered list of init modules, then loads each from `core/` via `load-file`. `init-mac` is wrapped in `(when (eq system-type 'darwin) ...)`. This list is the **canonical registry** of all modules.
3. **`core/init-util.el`** (first in load order) — Defines custom macros (`add-hook!`, `defadvice!`, etc.) used by every other module. Always loaded before anything else.
4. **`core/init-straight.el`** (second) — Bootstraps `straight.el` and configures `use-package` defaults: `use-package-always-defer` is `t` in interactive sessions, `use-package-always-demand` is `t` for daemon frames. Must load before any file that uses `use-package`.
5. Remaining `core/init-*.el` loaded in `+init-files` order. Later files depend on earlier ones — load order is load-bearing (e.g. `init-ui` defines `+load-theme` before `init-mac` hooks it into `ns-system-appearance-change-functions`).

### The `+init-files` list (canonical, in order)

`init-util`, `init-straight`, `init-basic`, `init-ui`, `init-xterm`, `init-ghostel`, `init-mac` (Darwin only), `init-completion`, `init-tools`, `init-keybinding`, `init-highlight`, `init-edit`, `init-spell`, `init-window`, `init-dired`, `init-eshell`, `init-prog`, `init-scheme`, `init-writing`, `init-org`, `init-vcs`, `init-browser`, `init-ibuffer`, `init-dict`, `init-modeline`, `init-tabbar`, `init-ai`, `init-chat`, `init-pdf`, `init-test`.

Commented out: `init-ime`, `init-modal`.

Note: `init-elfeed` is loaded last in `+init-files` (not commented out) despite the `.elc` being present on disk.

**Note:** Despite the name, `init-test.el` is **not** a test suite and **is loaded** — it contains JDTLS (Java LSP) contact config, extra `eglot-server-programs` entries (verilog, java), and a `cargo-xtask-install-server` helper for rust-analyzer development. There is no test suite in this config (see "Verification" below). It loads **last** in `+init-files`.

## Custom macros (defined in `core/init-util.el`)

These are adapted from DOOM Emacs and used throughout:

- **`add-hook!`** — Add N functions to M hooks with optional `:local`, `:append`, `:depth`, `:remove`, `:call-immediately`, `:unless-daemonp-call-immediately`. Functions can be inline `defun` forms.
- **`defadvice!`** — Define a named function and `advice-add` it to specified places. Syntax: `(defadvice! NAME ARGLIST [WHERE PLACES...] BODY)` where WHERE is a keyword like `:around`/`:after`/`:before`.
- **`+advice-pp-to-prin1!`** — Advise a function to temporarily replace `pp` with `prin1`, reducing cache file sizes (used for `saveplace`, `recentf`).
- **`defun-call!`** — Define a function and optionally call it immediately with `:call-with ARGS`.
- **`+temp-buffer-p`** — Returns t if a buffer's name starts with a space (Emacs convention for temp buffers). Used as a guard to prevent modes from activating in temp buffers.
- **`+unfill-region`** — Inverse of `fill-region`: replaces newlines with spaces in the region.

## Key conventions

- **`+` prefix**: Custom/private functions use a `+` prefix (e.g. `+setup-fonts`, `+load-theme`, `+disable-frame-chrome`). This distinguishes project-defined functions from third-party ones.
- **Advice naming**: Functions defined with `defadvice!` use a suffix indicating the advice type — `-a` for `:around`, `-h` for hook functions. Example: `+disable-autosave-notification-a`.
- **`:unless-daemonp-call-immediately`**: Common `add-hook!` pattern — code runs immediately in interactive sessions but defers for daemon frames (where the frame may not exist yet). Used for font setup, theme loading, etc.
- Paths are relative to `user-emacs-directory` (`.emacs.d/`).
- Autosave files go to `autosaves/`, backup files to `backups/` (both gitignored).
- The custom file is `custom.el` (gitignored, not the default location).
- Lexical binding is declared on line 1 of every file via `;;; -*- lexical-binding: t -*-` or `;; -*- lexical-binding: t; -*-`.
- Most packages use `:straight t`; built-in packages use `:straight nil` (or `:straight (:type built-in)`).
- **`:straight nil` for sub-packages**: When a package ships extensions in subdirectories (vertico, corfu, ghostel), those extensions use `:straight nil` with `:after <parent>` — they're already installed by the parent package.
- **`:straight (:host github :repo "user/repo")`**: For packages not on MELPA/ELPA, or forked packages.
- **`with-eval-after-load` for cross-module integration**: When one package extends another that may not be loaded yet, use `with-eval-after-load` rather than a hard `:after` dependency. Used for savehist↔corfu, diff-hl↔magit, project↔ghostel.
- **Local-path packages**: `doric-themes` is loaded from `/Users/dragon/Documents/Emacs` via `:load-path`, not from a package archive. (`gptel-magit` previously used a local `~/code/gptel-magit/` `:load-path` too, but is now straight-installed from GitHub `roife/gptel-magit`.)

## Theme and UI (`core/init-ui.el`)

- **Theme**: Uses `doric-themes` — `doric-fire` (dark) and `doric-tiger` (light). Loaded from a local path (`/Users/dragon/Documents/Emacs`), not straight.el. `:demand t`.
- **Theme auto-detection**: On macOS, uses `ns-system-appearance` to detect dark/light mode. On other platforms, defaults to dark for GUI, and matches terminal `background-mode` for TTY. The `+load-theme` function is defined in `init-ui.el`.
- **Theme auto-switching on macOS**: `init-mac.el` hooks into `ns-system-appearance-change-functions` to call `+load-theme` when system dark/light mode changes. This means `init-ui.el` must load before `init-mac.el`.
- **Fonts**: Primary: `MonoLisaCode` (size 14 on macOS, 26 elsewhere); `MonoLisaText` for `variable-pitch`. CJK (`han`, `cjk-misc`): `LXGW WenKai Mono Screen`. Emoji: `Apple Color Emoji` (macOS, rescaled 0.79) or `Noto Color Emoji` (other platforms).
- **UI features**: ligature-mode (in prog/markdown/org modes), scrollview (scroll progress in fringe, from `roife/scrollview.el`), window-divider-mode, pixelwise resize, custom fringe bitmaps.

## Ghostel terminal emulator (`core/init-ghostel.el`)

Ghostel replaces `ansi-term` as the primary terminal emulator. It uses Ghostty's Zig-based VT engine via a native dynamic module. By default, the native module auto-downloads a prebuilt binary (`ghostel-module-auto-install` = `'download`) — no build tools needed. Bound to `C-x m`; `ghostel-project` / `ghostel-project-list-buffers` are registered on `project-switch-commands` (after `project` loads).

**Sub-packages** (loaded via `:straight nil` — they ship with the main `ghostel` package):
- **`ghostel-compile`** — Routes `M-x compile` / `project-compile` output through Ghostel buffers instead of `*compilation*`. Enabled globally via `ghostel-compile-global-mode` on `after-init`.
- **`ghostel-comint`** — Routes comint-based REPLs (`run-python`, `run-scheme`, `sql-*`) through Ghostel. Enabled globally on `after-init`.
- **`ghostel-eshell`** — When a visual command (htop, less, vim) runs in Eshell, it transparently spawns a Ghostel buffer and returns to Eshell when the command exits. Hooked on `eshell-load`.

**Input modes** (5 modes, toggled via `C-c` prefixes; see the file's commentary for the full table): `semi-char` (default, `C-c C-j`), `char` (`C-c M-d`, all keys to terminal), `emacs` (`C-c C-e`, read-only), `copy` (`C-c C-t`, frozen for selection), `line` (`C-c C-l`, local editing).

**TRAMP integration**: When `default-directory` is a TRAMP path (`/ssh:host:/path/`), `M-x ghostel` starts a remote shell. `ghostel-tramp-shells` configures the shell per TRAMP method (ssh/scp use login-shell→bash fallback; docker/podman use `/bin/sh`). `ghostel-tramp-shell-integration` is scoped to `("ssh" "scp")`; `ghostel-ssh-install-terminfo` is `'auto` (follows integration setting).

## AI integration (`core/init-ai.el`)

All DeepSeek backends share one API key sourced from `auth-source` via `gptel-api-key-from-auth-source`.

- **`gptel`** — LLM chat client. Two DeepSeek backends:
  - `DeepSeek-thinking` (default `gptel-backend`, `:stream t`, `:request-params '(:thinking (:type "enabled"))`) — used for chat. Model: `deepseek-v4-flash` (the var `gptel-model`). Default chat format: `org-mode`. `gptel-confirm-tool-calls` is nil. Hooks: `gptel-auto-scroll` (post-stream), `gptel-end-of-response` (post-response).
  - `+gptel-rewrite-translate-to-chinese` — translates the active region to Simplified Chinese via `gptel-rewrite`. Bound to `C-c r t` and `T` in `embark-region-map` (loads `gptel-rewrite` on demand).
- **`gptel-agent`** — `:after gptel`, calls `gptel-agent-update` at config time.
- **`gptel-quick`** — `karthink/gptel-quick`, `:after (gptel embark)`. One-line queries from `embark-general-map` (`?`). Separate `DeepSeek-quick` backend with thinking **disabled**, model `deepseek-v4-flash`, 500-word cap, Chinese "一句话不分行解释：" system message.
- **`gptel-magit`** — AI-generated commit messages in Magit. Conventional Commits style (`gptel-magit-commit-prompt`), `gptel-magit-body-length` 72. Now straight-installed from GitHub `roife/gptel-magit` (the earlier local `~/code/gptel-magit/` recipe is gone). Installed on `magit-mode-hook`.
- **`codex-ide`** — `dgillis/emacs-codex-ide`. `codex-ide-session-mode` is also referenced (as a major mode) in `init-completion.el` — corfu and cape enable in buffers of that mode (see the hook lists there).
- **`claude-code-ide`** — `manzaltu/claude-code-ide.el`, `:after (ghostel project)`. Bridges Emacs ↔ Claude Code CLI via MCP so Claude sees current file/selection/xref/diagnostics; diffs open in `ediff`. Terminal backend is `ghostel` (uses this config's native module), laid out as a right side-window that doesn't steal focus. Bound to `C-c C-'` (`claude-code-ide-menu`). `claude-code-ide-enable-execute-code` is `t` (lets Claude eval Elisp via the `executeCode` MCP tool); `claude-code-ide-emacs-tools-setup` exposes built-in Emacs MCP tools (xref, treesit-info, imenu-list-symbols, project-info). Diagnostics backend is `auto` (auto-detects flymake, which is what `init-prog` uses).

Note: `agent-shell` (Codex via ACP) remains commented out in `init-tools.el`.

## Tree-sitter (`core/init-prog.el`)

`treesit-enabled-modes` is set to `t` (enable all built-in tree-sitter modes), `treesit-auto-install-grammar` is `'always` (grammars auto-install from GitHub on first use), and `treesit-font-lock-level` is 4 (maximum). Individual language packages (`rust-mode`, `go-mode`, etc.) are declared separately; `rust-mode` sets `rust-mode-treesitter-derive t` to use the ts mode. Note: `typst-ts-mode` is commented out.

## Package ecosystem

| Concern | Packages |
|---|---|
| Completion UI | vertico (+ `extensions/*.el`: directory, quick, multiform), corfu (+ history, popupinfo, quick extensions), orderless, marginalia |
| Completion commands/tools | consult, consult-dir, consult-eglot, embark, embark-consult, avy-embark-collect, cape, tempel, tempel-collection, eglot-tempel |
| LSP | eglot, eglot-booster, consult-eglot; JDTLS contact fn in `init-test.el` |
| VC | magit, forge, diff-hl, magit-todos, browse-at-remote, git-link, abridge-diff, git-modes, smerge-mode; difftastic via custom `+magit-*-with-difftastic` fns |
| AI | gptel, gptel-agent, gptel-quick, gptel-magit, codex-ide, claude-code-ide |
| Programming | citre (ctags), dumb-jump (xref fallback), quickrun, indent-bars, flymake, geiser + geiser-racket, treesit, envrc (direnv), cargo, rust-playground, rmsbolt, skewer-mode, webpaste |
| Terminal | ghostel, ghostel-compile, ghostel-comint, ghostel-eshell |
| Writing | org-mode, markdown-mode, auctex (LaTeX), cdlatex, reftex, pangu-spacing |
| Org extensions | org-modern, org-modern-indent, org-appear, org-pomodoro, valign |
| UI | doric-themes (local path), ligature, scrollview, breadcrumb (header-line), custom modeline |
| Editing | ws-butler, edit-indirect, puni, embrace, easy-kill, mwim, beginend, dogears, vundo, undo-fu-session, undo-hl |
| Windows | ace-window, winner, popper, zoom, auto-dim-other-buffers |
| Persistence | saveplace, recentf, savehist |
| Remote | tramp (ssh), exec-path-from-shell |
| Communication | telega, telega-dired-dwim |
| PDF | reader (MonadicSheep/emacs-reader, Codeberg, native `render-core.dylib` built via `make`; `pdf-tools` is commented out) |
| Dictionary | osx-dictionary (macOS), google-this (`C-, w`) |
| Terminal graphics | kitty-graphics (cashmeredev/kitty-graphics.el, tty-setup hook for inline images) |
| Language modes | go-mode, haskell-mode, rust-mode, swift-mode, verilog-mode, web-mode, yaml-mode, toml-mode, csv-mode/rainbow-csv, graphviz-dot-mode, llvm-mode, agda (when `agda-mode` executable present) |
| macOS | osx-dictionary |

## Keybindings

### Global (defined in `core/init-keybinding.el`)
Super-key (`s-`) bindings: `s-s` save, `s-x` kill-region, `s-c` copy-region-as-kill, `s-v` yank, `s-z` undo, `s-Z` undo-redo, `s-a` mark-whole-buffer, `s-w` tab-close, `s-t` tab-new, `s-o` other-window, `s-,` xref-go-back.

### Search/navigation (defined in consult `:bind` in `core/init-completion.el`)
- `s-l` consult-line, `s-f` consult-ripgrep, `s-d` consult-fd, `s-g` consult-goto-line
- `C-c i` consult-imenu, `C-c I` consult-imenu-multi

### Embark (defined in `core/init-completion.el`)
- `C-.` embark-act, `s-.` embark-dwim, `M-.` embark-dwim (set globally via `keymap-global-set`, overrides default `xref-find-definitions`)
- `C-h B` embark-bindings

### Custom `C-,` prefix (leader-like)
`C-,` is used as an ad-hoc prefix across modules: `C-, o` browse-url-at-point, `C-, e` browse-url-emacs (`init-tools`), `C-, w` google-this (`init-dict`), `C-, g l/c/h` git-link variants (`init-vcs`), `C-, .`/`C-, ,`/`C-, l` avy-goto (`init-keybinding`), `C-, j`/`C-, c` link-hint open/copy.

### VC (defined in `core/init-vcs.el`)
- `C-x g` magit
- `C-, g l` git-link, `C-, g c` git-link-commit, `C-, g h` git-link-homepage
- Magit transient extensions: `D` difftastic-diff (dwim), `S` difftastic-show (via `+magit-diff-with-difftastic` / `+magit-show-with-difftastic`)

### Terminal
- `C-x m` ghostel (defined in `core/init-ghostel.el`)

### Programming (defined in `core/init-prog.el`)
- `C-c r` quickrun
- `C-c c j` citre-jump (fallback to `xref-find-definitions`), `C-c c k` citre-jump-back, `C-c c p` citre-peek, `C-c c a` citre-ace-peek, `C-c c u` citre-update-this-tags-file
- `C-c f ]` flymake-goto-next-error, `C-c f [` flymake-goto-prev-error, `C-c f b` flymake-show-buffer-diagnostics
- In eglot-mode-map: `M-RET` eglot-code-actions, `M-/` eglot-find-typeDefinition, `M-?` xref-find-references

### macOS
- `C-c d i` osx-dictionary-search-input, `C-c d d` osx-dictionary-search-pointer

### Chinese punctuation translation
Chinese punctuation is translated to English equivalents in keybindings via `key-translation-map` for `C-`, `M-`, `s-`, and `H-` prefixes (defined in `init-keybinding.el`).

## External dependencies

Required: `rg` (ripgrep), `fd`, `aspell`, `readability-cli` (for `eww`), `difft`/`difftastic` (structural diff, used by `+magit-*-with-difftastic`). The `reader` PDF package runs a `:pre-build` (`make all`) to produce `render-core.dylib`, so a C toolchain is needed on first install. The `README.md` is stale — it lists `delta`, `Sarasa Gothic`, and `Symbola`, none of which the code references; `difftastic` is the active diff tool and the actual CJK font is `LXGW WenKai Mono Screen`. Fonts actually used: MonoLisaCode (primary), MonoLisaText (variable-pitch), LXGW WenKai Mono Screen (CJK), Apple Color Emoji / Noto Color Emoji (emoji). Optional: `gls` (GNU coreutils `ls`, for dired on macOS), `zstd` (for undo-fu-session compression), `tdlib` (for telega, via Homebrew `tdlib`), `agda-mode` (for agda), `raco` (for geiser-racket / SICP `#lang sicp`).

## Adding a new package

Add a `use-package` form in the relevant `core/init-*.el`. If it needs a new init file, add its symbol to `+init-files` in `init.el` (order matters — later files can depend on earlier ones). Avoid adding to the front of the list (before `init-straight.el`) since `use-package` isn't configured yet.

For sub-packages that ship with a parent package (like vertico extensions, corfu extensions, ghostel sub-modules), use `:straight nil` with `:after <parent>`.

## Verification

There is no test suite. Manual verification — load Emacs and exercise the changed functionality. `init.el` registers a `window-setup-hook` lambda that prints `window-setup` and `after-init` timings to `*Messages*`, useful for spotting startup regressions. (There is no `efs/display-startup-time` function — that earlier note was inaccurate.) For finer-grained startup profiling, use `M-x emacs-init-time` or wrap suspect forms in `(benchmark-run ...)`.

When verifying a change to one module, you can reload just that file in a running Emacs (`M-x load-file RET core/init-FOO.el RET`) rather than restarting, since `use-package` forms are idempotent for most settings. Note `use-package-always-defer` is `t` in interactive sessions, so a package's `:config` block only runs after the package is first loaded — exercise the feature that triggers it (e.g., open a `python-ts-mode` file to load `python-ts-mode`'s config) before assuming a change took effect.

## Scheme (`core/init-scheme.el`)

Scheme REPL via Geiser. Default implementation is Racket (`scheme-program-name`); `geiser-active-implementations` covers Racket, Guile, and MIT. `geiser-racket` is installed separately (`:after geiser`). Geiser auto-starts in `scheme-mode` (`geiser-mode-start-repl-p` t). Eval bindings in `scheme-mode-map`: `C-c C-z` switch-to-repl, `C-c C-b` eval-buffer, `C-c C-r` eval-region, `C-M-x` eval-definition, `C-c C-e` eval-last-sexp, `C-c C-d` doc-at-point. For SICP, use Racket with `#lang sicp` (install via `raco pkg install sicp`).
