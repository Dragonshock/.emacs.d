;;; -*- lexical-binding: t -*-
;;; init-agent-shell.el --- Grok Build + Claude Code via agent-shell (ACP) -*- lexical-binding: t; -*-

;; Dual ACP agents in agent-shell, aimed at a Zed-like Agent panel:
;; pick Grok Build or Claude Code, side panel chat, model/mode in-session.
;;
;; Grok uses the OFFICIAL agent-shell-xai.el (upstream PR #720) — process
;; contract, welcome screen and auth all come from the package:
;;   command: grok agent stdio       (absolute path set below)
;;   auth:    ACP authenticate with `cached_token' (~/.grok/auth.json,
;;            written by `grok login'; no API key involved)
;; Claude:  claude-agent-acp (npm: @agentclientprotocol/claude-agent-acp)
;;          — not the bare `claude' CLI; that is only for `claude login'.
;;
;; Grok model: ACP IDs like "grok-4.5" via `agent-shell-xai-default-model-id'.
;; Zed's default_model "grok-build" is NOT a valid Grok ACP model id.
;;
;; MCP: agent-shell-mcp-servers stays nil — each agent uses its own native
;; MCP/plugins (same idea as Zed agent-owned context servers).
;;
;; Keys (agent-shell DWIM):
;;   C-c C-g          start or reuse a shell; picker when creating a NEW one
;;   C-u C-c C-g      force a new shell (picker: Grok / Claude) — open 2nd agent
;;   C-u C-u C-c C-g  pick among existing shells
;;   C-c C-v          set session model (when advertised)
;;   C-c C-m          set session mode
;;   C-c C-t          set thought level (when advertised)
;;   C-<tab>          cycle session mode
;;   M-x +agent-shell-start-grok    always new Grok
;;   M-x +agent-shell-start-claude  always new Claude
;;
;; Preferred agent: (preselect . grok-build) — still shows the picker with
;; Grok first (grok-build is the official config's :identifier).  Never use
;; a bare symbol (that skips the picker).
;;
;; Prerequisites:
;;   - Emacs 29.1+
;;   - Grok: ~/.grok/bin/grok + `grok login'
;;   - Claude: `npm i -g @agentclientprotocol/claude-agent-acp'
;;             + `claude login' (or existing subscription login)

(eval-when-compile
  (require 'cl-lib))

;;; Paths

(defconst +agent-shell-grok-bin
  (expand-file-name "~/.grok/bin/grok")
  "Absolute path to the Grok Build CLI.
Same binary as `+telega-grok-bin' (init-social.el) uses for unread
summaries.")

(defconst +agent-shell-bin-dirs
  (list (file-name-directory +agent-shell-grok-bin)
        (expand-file-name "~/.local/bin")
        "/opt/homebrew/bin"
        "/usr/local/bin")
  "Directories that may hold ACP agent CLIs (grok, claude-agent-acp).

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

;;; Entry commands (always force a NEW shell; DWIM reuse is on C-c C-g)

(defun +agent-shell-start-grok ()
  "Start a new interactive Grok Build agent shell (official config)."
  (interactive)
  (require 'agent-shell)
  (require 'agent-shell-xai)
  (+agent-shell-ensure-path)
  (agent-shell--dwim :config (agent-shell-xai-make-grok-config)
                     :new-shell t))

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

;;; Package setup

(use-package agent-shell
  :straight t
  ;; Autoload only library entry points; +agent-shell-start-* are defined
  ;; in this file when init loads it (do not map them to the agent-shell feature).
  :commands (agent-shell agent-shell-anthropic-start-claude-code
                         agent-shell-xai-start-grok)
  :bind (("C-c C-g" . agent-shell))
  :config
  (+agent-shell-ensure-path)
  ;; Official Grok Build support (agent-shell-xai.el, upstream PR #720).
  (require 'agent-shell-xai)

  ;; Absolute CLI path (do not depend on PATH alone), preferred model, and
  ;; inherited environment — the official client passes this list verbatim,
  ;; and `grok' needs HOME/PATH from the login environment (~/.grok/auth.json).
  (setq agent-shell-xai-acp-command (list +agent-shell-grok-bin "agent" "stdio")
        agent-shell-xai-default-model-id "grok-4.5"
        agent-shell-xai-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; Dual base: Grok Build (official config) + Claude Code (claude-agent-acp).
  ;; preselect grok-build: picker still shown on NEW shell; Grok first.
  (setq agent-shell-agent-configs
        (list #'agent-shell-xai-make-grok-config
              #'agent-shell-anthropic-make-claude-code-config)
        agent-shell-preferred-agent-config '(preselect . grok-build)
        ;; Agents own native MCP/plugins; editor-forwarded MCP is opt-in later.
        agent-shell-mcp-servers nil
        agent-shell-display-action
        '((display-buffer-reuse-window display-buffer-in-direction)
          (direction . right)
          (window-width . 0.42)
          (reusable-frames . visible)))

  ;; Only agent-shell defcustom with a :set setter (validates the value);
  ;; use setopt so it runs — agent-shell is loaded here, so the setter exists.
  (setopt agent-shell-session-strategy 'prompt)

  (unless (or (file-executable-p +agent-shell-grok-bin)
              (executable-find "grok"))
    (warn "Cannot find Grok Build CLI at %s. Install it and run `grok login'."
          +agent-shell-grok-bin))

  (unless (executable-find "claude-agent-acp")
    (warn "Cannot find claude-agent-acp. Install: npm i -g @agentclientprotocol/claude-agent-acp (then `claude login')."))

  ;; Avoid zoom thrashing the agent window (same idea as former grok-ide).
  (with-eval-after-load 'zoom
    (when (boundp 'zoom-ignored-major-modes)
      (add-to-list 'zoom-ignored-major-modes 'agent-shell-mode))))

(provide 'init-agent-shell)

;;; init-agent-shell.el ends here
