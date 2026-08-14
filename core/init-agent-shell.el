;;; -*- lexical-binding: t -*-
;;; init-agent-shell.el --- Grok Build + Cursor + Claude Code + Pi via agent-shell (ACP) -*- lexical-binding: t; -*-

;; ACP agents in agent-shell (Grok Build, Cursor, Claude Code, Pi).
;; UX aligned with agent-shell author (viewport-first) + package same-window
;; display (applied 2026-08-03: V1 D1a V3 V4 from
;; dev-docs/notes/agent-shell-ux-align-recommendations-2026-08-02.md).
;;
;; Grok uses the OFFICIAL agent-shell-xai.el (upstream PR #720) — process
;; contract, welcome screen and auth all come from the package:
;;   command: grok agent stdio       (absolute path set below)
;;   auth:    ACP authenticate with `cached_token' (~/.grok/auth.json,
;;            written by `grok login'; no API key involved)
;; Cursor:  official Cursor CLI ACP (`agent acp`); auth is `agent login'
;;          outside Emacs (agent-shell-cursor-authentication :none).
;; Claude:  claude-agent-acp (npm: @agentclientprotocol/claude-agent-acp)
;;          — not the bare `claude' CLI; that is only for `claude login'.
;; Pi:      pi-acp adapter (npm: pi-acp) → spawns `pi --mode rpc'
;;          — agent-shell never talks to bare `pi' over ACP; see
;;          dev-docs/notes/how-agent-shell-works-with-pi-2026-08-02.md
;;
;; Grok model: new sessions prefer "grok-4.6" via
;; `agent-shell-xai-default-model-id'.  Do NOT pass `-m' on the CLI command
;; (that pins the process).  Switch mid-session with C-c C-v (or viewport `v')
;; among advertised ACP ids (`grok-4.6', `grok-build', `grok-4.5', …).
;; `grok-build' as an ACP model id is distinct from the agent-shell config
;; :identifier `grok-build' used in `agent-shell-preferred-agent-config'.
;;
;; Grok effort: Grok Build advertises reasoning effort as ACP session *modes*
;; (minimal / low / medium / high / xhigh), not thought_level.  Switch with
;; C-c C-m, C-<tab>, or viewport `s'.  Leave
;; `agent-shell-xai-default-session-mode-id' nil so effort is not pinned;
;; do not pass `--effort' on the CLI command.  C-c C-t is thought_level
;; (Claude/Codex); Grok typically does not advertise that category.
;;
;; MCP: agent-shell-mcp-servers stays nil — each agent uses its own native
;; MCP/plugins (same idea as Zed agent-owned context servers).
;;
;; Keys (agent-shell DWIM):
;;   C-c C-g          start or reuse a shell; picker only when creating a NEW one
;;   C-u C-c C-g      force a new shell (picker: Grok / Cursor / Claude / Pi)
;;   C-u C-u C-c C-g  pick among existing shells
;;   C-c c            always new Cursor (does not reuse the Grok shell)
;;   C-c C-;          compose a multi-line prompt (agent-shell-prompt-compose)
;;   C-c C-v          set session model (when advertised)
;;   C-c C-m          set session mode (Grok: reasoning effort, incl. xhigh)
;;   C-c C-t          set thought level (when advertised; not Grok effort)
;;   C-<tab>          cycle session mode
;;   C-c C-o          switch viewport ↔ shell buffer
;;   Viewport view:   y / c / m / r (and ? for help)
;;                    v model, s mode/effort, t thought level
;;   M-x +agent-shell-start-grok    always new Grok
;;   M-x +agent-shell-start-cursor  always new Cursor
;;   M-x +agent-shell-start-claude  always new Claude
;;   M-x +agent-shell-start-pi      always new Pi
;;
;; Preferred agent: (preselect . grok-build) — still shows the picker with
;; Grok first (grok-build is the official config's :identifier).  Never use
;; a bare symbol (that skips the picker).
;;
;; Cursor does not appear on a plain C-c C-g when a Grok shell already
;; exists in the project: DWIM reuses that shell and never opens the
;; agent picker.  After Grok starts, the next minibuffer is Grok's ACP
;; *session* list, not the agent list.  Use C-u C-c C-g or C-c c.
;;
;; Prerequisites:
;;   - Emacs 29.1+
;;   - Grok: ~/.grok/bin/grok + `grok login'
;;   - Cursor: ~/.local/bin/agent + `agent login'
;;             (curl https://cursor.com/install -fsS | bash; needs `agent acp')
;;   - Claude: `npm i -g @agentclientprotocol/claude-agent-acp'
;;             + `claude login' (or existing subscription login)
;;   - Pi: `pi` + `pi-acp` on PATH (Homebrew/npm); absolute paths set below

(eval-when-compile
  (require 'cl-lib))

;;; Paths

(defconst +agent-shell-grok-bin
  (expand-file-name "~/.grok/bin/grok")
  "Absolute path to the Grok Build CLI.
Same binary as `+telega-grok-bin' (init-social.el) uses for unread
summaries.")

(defconst +agent-shell-cursor-bin
  (expand-file-name "~/.local/bin/agent")
  "Absolute path to the Cursor CLI (`agent acp`).")

(defconst +agent-shell-pi-acp-bin
  "/opt/homebrew/bin/pi-acp"
  "Absolute path to the pi-acp ACP adapter (not bare `pi').")

(defconst +agent-shell-pi-bin
  "/opt/homebrew/bin/pi"
  "Absolute path to the pi coding-agent CLI.
Passed to pi-acp as PI_ACP_PI_COMMAND so the adapter does not rely on PATH.")

(defconst +agent-shell-bin-dirs
  (list (file-name-directory +agent-shell-grok-bin)
        (file-name-directory +agent-shell-cursor-bin)
        (expand-file-name "~/.local/bin")
        "/opt/homebrew/bin"
        "/usr/local/bin")
  "Directories that may hold ACP agent CLIs (grok, agent, claude-agent-acp, pi-acp, pi).

GUI and daemon Emacs often lack npm global bins; keep Homebrew and
~/.local/bin here.  If `npm prefix -g` is elsewhere, add \"PREFIX/bin\".")

(defun +agent-shell-ensure-path ()
  "Ensure ACP agent CLI directories are on `exec-path' and process PATH."
  (dolist (dir +agent-shell-bin-dirs)
    (when (file-directory-p dir)
      (add-to-list 'exec-path dir)
      (let ((path (getenv "PATH")))
        (unless (and path (string-match-p (regexp-quote dir) path))
          (setenv "PATH" (concat dir path-separator (or path ""))))))))

(defun +agent-shell-resolved-cursor-bin ()
  "Return the Cursor CLI (`agent') path, or nil."
  (+agent-shell-ensure-path)
  (or (and (file-executable-p +agent-shell-cursor-bin)
           +agent-shell-cursor-bin)
      (executable-find "agent")))

;;; Entry commands (always force a NEW shell; DWIM reuse is on C-c C-g)

(defun +agent-shell-start-grok ()
  "Start a new interactive Grok Build agent shell (official config).

Requires `+agent-shell-grok-bin' (or `grok' on PATH) and a prior
`grok login' so ACP can authenticate with `cached_token'."
  (interactive)
  (require 'agent-shell)
  (require 'agent-shell-xai)
  (+agent-shell-ensure-path)
  (unless (or (file-executable-p +agent-shell-grok-bin)
              (executable-find "grok"))
    (user-error
     "Cannot find Grok Build CLI at %s. Install it and run `grok login'."
     +agent-shell-grok-bin))
  (agent-shell--dwim :config (agent-shell-xai-make-grok-config)
                     :new-shell t))

(defun +agent-shell-start-cursor ()
  "Start a new interactive Cursor agent shell (official ACP).

Requires `+agent-shell-cursor-bin' (or `agent' on PATH) and a prior
`agent login'.  Needs a 2026+ Cursor CLI that provides `agent acp'.
Does not reuse an existing Grok shell."
  (interactive)
  (require 'agent-shell)
  (require 'agent-shell-cursor)
  (let ((bin (+agent-shell-resolved-cursor-bin)))
    (unless bin
      (user-error
       "Cannot find Cursor CLI at %s. Install: curl https://cursor.com/install -fsS | bash ; then `agent login'."
       +agent-shell-cursor-bin))
    (setq agent-shell-cursor-acp-command (list bin "acp"))
    (agent-shell--dwim :config (agent-shell-cursor-make-agent-config)
                       :new-shell t)))

(defun +agent-shell (&optional arg)
  "Start or reuse an agent-shell (DWIM).

Plain \\[ +agent-shell] reuses this project's existing shell — typically
Grok — so the agent picker (and Cursor) never appears.  After Grok ACP
starts, the minibuffer lists Grok *sessions*, not agents.

Force the agent picker (Grok / Cursor / Claude / Pi) with a prefix
argument, or start Cursor with \\[ +agent-shell-start-cursor ]."
  (interactive "P")
  (require 'agent-shell)
  (let ((reused (and (not arg)
                     (not (derived-mode-p 'agent-shell-mode
                                          'agent-shell-viewport-view-mode
                                          'agent-shell-viewport-edit-mode))
                     (ignore-errors (seq-first (agent-shell-project-buffers))))))
    (agent-shell arg)
    (when (and reused (buffer-live-p reused))
      (let ((name (or (map-nested-elt (buffer-local-value 'agent-shell--state reused)
                                      '(:agent-config :mode-line-name))
                      (buffer-name reused))))
        (message "Reusing %s. Cursor is a different agent — C-u C-c C-g or C-c c."
                 name)))))

(defun +agent-shell-start-claude ()
  "Start a new interactive Claude Code agent shell (ACP).

Requires `claude-agent-acp' on PATH (npm package
@agentclientprotocol/claude-agent-acp) and a prior `claude login'
for subscription/login auth."
  (interactive)
  (require 'agent-shell)
  (require 'agent-shell-anthropic)
  (+agent-shell-ensure-path)
  (unless (executable-find "claude-agent-acp")
    (user-error
     "Cannot find claude-agent-acp. Install with: npm i -g @agentclientprotocol/claude-agent-acp"))
  (agent-shell--dwim :config (agent-shell-anthropic-make-claude-code-config)
                     :new-shell t))

(defun +agent-shell-start-pi ()
  "Start a new interactive Pi coding agent shell (via pi-acp).

agent-shell speaks ACP to `pi-acp'; pi-acp spawns `pi --mode rpc'.
Requires both binaries (see `+agent-shell-pi-acp-bin' and
`+agent-shell-pi-bin').  Use Pi's /login inside the shell if needed."
  (interactive)
  (require 'agent-shell)
  (require 'agent-shell-pi)
  (+agent-shell-ensure-path)
  (unless (file-executable-p +agent-shell-pi-acp-bin)
    (user-error
     "Cannot find pi-acp at %s. Install: npm i -g pi-acp" +agent-shell-pi-acp-bin))
  (unless (file-executable-p +agent-shell-pi-bin)
    (user-error
     "Cannot find pi at %s. Install: npm i -g @earendil-works/pi-coding-agent"
     +agent-shell-pi-bin))
  (agent-shell--dwim :config (agent-shell-pi-make-agent-config)
                     :new-shell t))

;; Bind outside use-package :bind.  Those keys would otherwise autoload
;; `+agent-shell' / `+agent-shell-start-cursor' from the agent-shell
;; feature, overwriting the defuns in this file.
(global-set-key (kbd "C-c C-g") #'+agent-shell)
(global-set-key (kbd "C-c c") #'+agent-shell-start-cursor)

;;; Package setup

(use-package agent-shell
  :straight t
  ;; Autoload only library entry points; +agent-shell-start-* are defined
  ;; in this file when init loads it (do not map them to the agent-shell feature).
  :commands (agent-shell agent-shell-anthropic-start-claude-code
                         agent-shell-xai-start-grok
                         agent-shell-cursor-start-agent
                         agent-shell-pi-start-agent
                         agent-shell-prompt-compose)
  :bind (;; V3: multi-line compose (works with or without prefer-viewport).
         ("C-c C-;" . agent-shell-prompt-compose))
  :config
  (+agent-shell-ensure-path)
  ;; Official Grok Build support (agent-shell-xai.el, upstream PR #720).
  (require 'agent-shell-xai)
  (require 'agent-shell-cursor)
  (require 'agent-shell-anthropic)
  (require 'agent-shell-pi)

  ;; Absolute CLI path (do not depend on PATH alone) and inherited
  ;; environment — the official client passes this list verbatim, and
  ;; `grok' needs HOME/PATH from the login environment (~/.grok/auth.json).
  ;; Prefer grok-4.6 for new sessions; do not pass `-m' / `--effort' (those
  ;; pin the process).  Switch model with C-c C-v; effort with C-c C-m.
  (setq agent-shell-xai-acp-command (list +agent-shell-grok-bin "agent" "stdio")
        agent-shell-xai-default-model-id "grok-4.6"
        agent-shell-xai-default-session-mode-id nil
        agent-shell-xai-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; Cursor: official `agent acp'.  Auth is an existing `agent login'
  ;; (:none — no ACP authenticate).  Do not pass `--model' (CLI default).
  ;; Prefer ~/.local/bin/agent; fall back to `agent' on PATH (GUI Emacs).
  (setq agent-shell-cursor-acp-command
        (list (or (+agent-shell-resolved-cursor-bin) +agent-shell-cursor-bin)
              "acp")
        agent-shell-cursor-authentication
        (agent-shell-cursor-make-authentication :none t)
        agent-shell-cursor-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; Pi: ACP adapter + pin pi binary for the adapter (daemon-safe).
  (setq agent-shell-pi-acp-command (list +agent-shell-pi-acp-bin)
        agent-shell-pi-environment
        (agent-shell-make-environment-variables
         "PI_ACP_PI_COMMAND" +agent-shell-pi-bin
         :inherit-env t))

  ;; Grok Build + Cursor + Claude Code + Pi (pi-acp).
  ;; preselect grok-build: picker still shown on NEW shell; Grok first.
  (setq agent-shell-agent-configs
        (list #'agent-shell-xai-make-grok-config
              #'agent-shell-cursor-make-agent-config
              #'agent-shell-anthropic-make-claude-code-config
              #'agent-shell-pi-make-agent-config)
        agent-shell-preferred-agent-config '(preselect . grok-build)
        ;; Agents own native MCP/plugins; editor-forwarded MCP is opt-in later.
        agent-shell-mcp-servers nil
        ;; V1: author primary interaction (view latest turn + compose + y/c/m/r).
        agent-shell-prefer-viewport-interaction t
        ;; V4: expand tool-use fragments by default (thought stays folded).
        agent-shell-tool-use-expand-by-default t
        ;; D1a: package/author default — same-window (was right 0.42 Zed-style).
        agent-shell-display-action '(display-buffer-same-window))

  ;; Only agent-shell defcustom with a :set setter (validates the value);
  ;; use setopt so it runs — agent-shell is loaded here, so the setter exists.
  (setopt agent-shell-session-strategy 'prompt)

  ;; header-style STANDARD is (if (display-graphic-p) 'graphical 'text) with no
  ;; :set.  Daemon + use-package-always-demand loads under no GUI → freezes as
  ;; text.  Force graphical when a real GUI frame exists (web-mode pattern).
  (defun +agent-shell-force-graphic-header ()
    "Prefer graphical agent-shell header when a GUI frame is available."
    (when (display-graphic-p)
      (setq agent-shell-header-style 'graphical)))
  (+agent-shell-force-graphic-header)
  (add-hook 'server-after-make-frame-hook
            (lambda ()
              (when (display-graphic-p)
                (+agent-shell-force-graphic-header))))

  (unless (or (file-executable-p +agent-shell-grok-bin)
              (executable-find "grok"))
    (warn "Cannot find Grok Build CLI at %s. Install it and run `grok login'."
          +agent-shell-grok-bin))

  (unless (+agent-shell-resolved-cursor-bin)
    (warn "Cannot find Cursor CLI at %s. Install: curl https://cursor.com/install -fsS | bash ; then `agent login'."
          +agent-shell-cursor-bin))

  (unless (executable-find "claude-agent-acp")
    (warn "Cannot find claude-agent-acp. Install: npm i -g @agentclientprotocol/claude-agent-acp (then `claude login')."))

  (unless (file-executable-p +agent-shell-pi-acp-bin)
    (warn "Cannot find pi-acp at %s. Install: npm i -g pi-acp" +agent-shell-pi-acp-bin))

  (unless (file-executable-p +agent-shell-pi-bin)
    (warn "Cannot find pi at %s. Install: npm i -g @earendil-works/pi-coding-agent"
          +agent-shell-pi-bin))

  ;; Avoid zoom thrashing the agent window (same idea as former grok-ide).
  (with-eval-after-load 'zoom
    (when (boundp 'zoom-ignored-major-modes)
      (add-to-list 'zoom-ignored-major-modes 'agent-shell-mode))))

(provide 'init-agent-shell)

;;; init-agent-shell.el ends here
