;;; -*- lexical-binding: t -*-
;;; init-agent-shell.el --- Grok Build via agent-shell (ACP) -*- lexical-binding: t; -*-

;; Custom Grok agent for agent-shell, structured like upstream
;; `agent-shell-anthropic' (Claude), with a Zed-equivalent process
;; contract for Grok Build.
;;
;; Zed custom agent_servers (community / External Agents):
;;   command: ~/.grok/bin/grok
;;   args:    ["agent", "stdio"]
;;   default_model in Zed settings is not the same as ACP model IDs;
;;   Grok ACP advertises e.g. "grok-4.5" (see Available models on start).
;;
;; Auth: run `grok login' once outside Emacs (terminal/ghostel).  No API
;; key and no ACP authenticate request — same idea as Cursor `:none'.
;; Permission defaults come from ~/.grok/config.toml (e.g. always-approve).
;; Session modes (Plan / Always-approve / …) use upstream agent-shell:
;;   C-c C-m  set mode (minibuffer)   C-<tab>  cycle mode
;;
;; Keys:
;;   C-c C-g          start/reuse Grok agent shell (DWIM)
;;   C-u C-c C-g      force a new shell
;;   C-u C-u C-c C-g  pick an existing shell
;;   M-x +agent-shell-start-grok  always start a new Grok shell
;;
;; Prerequisites:
;;   - Emacs 29.1+
;;   - Grok Build CLI at ~/.grok/bin/grok (or ~/.local/bin/grok)
;;   - `grok login' completed

(eval-when-compile
  (require 'cl-lib))

;;; Customization (personal variables; mirror Claude's defcustoms)

(defconst +agent-shell-grok-bin
  (expand-file-name "~/.grok/bin/grok")
  "Absolute path to the Grok Build CLI (Zed agent_servers command).")

(defconst +agent-shell-grok-bin-dirs
  (list (file-name-directory +agent-shell-grok-bin)
        (expand-file-name "~/.local/bin"))
  "Directories that commonly hold the Grok Build CLI.")

(defvar +agent-shell-grok-acp-command
  (list +agent-shell-grok-bin "agent" "stdio")
  "Command and parameters for the Grok Build ACP client.

The first element is the executable; the rest are arguments.
Equivalent to Claude's `agent-shell-anthropic-claude-acp-command' and
to Zed's agent_servers command+args for Grok.

To hard-code flags, insert them before `stdio', e.g.:

  (setq +agent-shell-grok-acp-command
        (list +agent-shell-grok-bin \"agent\" \"-m\" \"grok-4.5\" \"stdio\"))

Or set `+agent-shell-grok-model' / `+agent-shell-grok-always-approve'
and leave this list at the default shape.")

(defvar +agent-shell-grok-model "grok-4.5"
  "Default ACP model ID for new Grok sessions.

Must be an ID from the agent's \"Available models\" list (e.g.
`grok-4.5').  Do not use Zed's `default_model' string `grok-build' —
that is not a valid Grok ACP model id and causes -32602
\"unknown model id\" during \"Setting model\".

When non-nil and `+agent-shell-grok-acp-command' still has the default
shape, inject `-m MODEL' before `stdio'.  Also used as
`:default-model-id' on the agent config (Claude-shaped ACP hook).
Set to nil to leave model selection entirely to the Grok CLI.")

(defvar +agent-shell-grok-always-approve nil
  "When non-nil, pass `--always-approve' to `grok agent'.

Default is nil: respect ~/.grok/config.toml (e.g. permission_mode
always-approve).  Only applied when the ACP command is still the
default shape.")

(defvar +agent-shell-grok-environment nil
  "Environment variables for the Grok ACP client.

Nil means inherit Emacs `process-environment' via
`agent-shell-make-environment-variables' with `:inherit-env t'
(needed for PATH/HOME after `grok login').

To customize, set after agent-shell loads, e.g.:

  (setq +agent-shell-grok-environment
        (agent-shell-make-environment-variables
         :inherit-env t
         \"HTTPS_PROXY\" \"http://127.0.0.1:7890\"))")

;;; Path helpers

(defun +agent-shell-ensure-path ()
  "Ensure Grok CLI directories are on `exec-path' and process PATH."
  (dolist (dir +agent-shell-grok-bin-dirs)
    (when (file-directory-p dir)
      (add-to-list 'exec-path dir)
      (let ((path (getenv "PATH")))
        (unless (and path (string-match-p (regexp-quote dir) path))
          (setenv "PATH" (concat dir path-separator (or path ""))))))))

(defun +agent-shell-grok--command-executable (cmd)
  "Normalize CMD from `+agent-shell-grok-acp-command' for comparison."
  (file-truename (expand-file-name cmd)))

(defun +agent-shell-grok--default-acp-command-p ()
  "Return non-nil if `+agent-shell-grok-acp-command' is still the default shape.

Accepts either the absolute `+agent-shell-grok-bin' or bare `grok' as
the executable, with args `agent' … `stdio'."
  (let* ((cmd (car +agent-shell-grok-acp-command))
         (params (cdr +agent-shell-grok-acp-command))
         (exe-ok (or (equal cmd "grok")
                     (and (stringp cmd)
                          (equal (+agent-shell-grok--command-executable cmd)
                                 (+agent-shell-grok--command-executable
                                  +agent-shell-grok-bin))))))
    (and exe-ok
         (equal (car params) "agent")
         (equal (car (last params)) "stdio"))))

(defun +agent-shell-grok--resolved-command ()
  "Return (COMMAND . PARAMS) for the Grok ACP process.

When `+agent-shell-grok-acp-command' is the default shape, inject
`+agent-shell-grok-model' (`-m') and optional always-approve between
`agent' and `stdio' (Zed process contract)."
  (let* ((cmd (car +agent-shell-grok-acp-command))
         (params (cdr +agent-shell-grok-acp-command)))
    (when (and (+agent-shell-grok--default-acp-command-p)
               (or +agent-shell-grok-model +agent-shell-grok-always-approve))
      (setq params
            (append
             '("agent")
             (when +agent-shell-grok-model
               (list "-m" +agent-shell-grok-model))
             (when +agent-shell-grok-always-approve
               '("--always-approve"))
             '("stdio"))))
    (cons cmd params)))

;;; Agent config (Claude-shaped: make-client → make-config → start)

(cl-defun +agent-shell-make-grok-client (&key buffer)
  "Create a Grok Build ACP client with BUFFER as context.

Mirrors `agent-shell-anthropic-make-claude-client': command from
`+agent-shell-grok-acp-command', environment from
`+agent-shell-grok-environment' (or inherit-env when nil)."
  (unless buffer
    (error "Missing required argument: :buffer"))
  (+agent-shell-ensure-path)
  (pcase-let ((`(,command . ,params) (+agent-shell-grok--resolved-command)))
    (agent-shell--make-acp-client
     :command command
     :command-params params
     :environment-variables
     (or +agent-shell-grok-environment
         (agent-shell-make-environment-variables :inherit-env t))
     :context-buffer buffer)))

(defun +agent-shell-grok-welcome-message (config)
  "Welcome message for Grok Build using shell-maker CONFIG."
  (let ((message (string-trim-left (shell-maker-welcome-message config) "\n")))
    (concat "\n\n"
            "  Grok Build (ACP via `grok agent stdio')\n"
            "  Default model: " (or +agent-shell-grok-model "(CLI default)") "\n"
            "  Auth: external — run `grok login' outside Emacs if needed\n"
            "  Modes: C-c C-m (set)  C-<tab> (cycle) when advertised\n"
            "\n"
            message)))

(defun +agent-shell-make-grok-config ()
  "Create a Grok Build agent configuration.

Returns an agent configuration alist using
`agent-shell-make-agent-config', parallel to
`agent-shell-anthropic-make-claude-code-config'."
  (agent-shell-make-agent-config
   :identifier 'grok
   :mode-line-name "Grok"
   :buffer-name "Grok"
   :shell-prompt "Grok> "
   :shell-prompt-regexp "Grok> "
   :welcome-function #'+agent-shell-grok-welcome-message
   ;; External auth (`grok login'); do not send ACP authenticate.
   :needs-authentication nil
   :client-maker (lambda (buffer)
                   (+agent-shell-make-grok-client :buffer buffer))
   ;; Claude-shaped default model hook + CLI `-m' (see resolved command).
   :default-model-id (lambda () +agent-shell-grok-model)
   ;; Leave session mode to Grok config / C-c C-m (no forced mode id).
   :default-session-mode-id (lambda () nil)
   :install-instructions
   "Install the Grok Build CLI to ~/.grok/bin/grok (see https://zed.dev/acp/agent/grok-build), then run `grok login' once outside Emacs."))

(defun +agent-shell-start-grok ()
  "Start a new interactive Grok Build agent shell.

Always forces a new shell (like `agent-shell-anthropic-start-claude-code').
For reuse/DWIM, use `agent-shell' bound to C-c C-g."
  (interactive)
  (require 'agent-shell)
  (agent-shell--dwim :config (+agent-shell-make-grok-config)
                     :new-shell t))

;;; Package setup

(use-package agent-shell
  :straight t
  :commands (agent-shell)
  :bind (("C-c C-g" . agent-shell))
  :config
  (+agent-shell-ensure-path)

  ;; Only Grok Build — expand later if you want Claude/Codex/etc. too.
  (setq agent-shell-agent-configs (list #'+agent-shell-make-grok-config)
        agent-shell-preferred-agent-config 'grok
        agent-shell-session-strategy 'prompt
        ;; No editor-forwarded MCP in phase 1; Grok owns native MCP/plugins.
        agent-shell-mcp-servers nil
        agent-shell-display-action
        '((display-buffer-reuse-window display-buffer-in-direction)
          (direction . right)
          (window-width . 0.42)
          (reusable-frames . visible)))

  (unless (or (file-executable-p +agent-shell-grok-bin)
              (executable-find "grok"))
    (warn "Cannot find Grok Build CLI at %s. Install it and run `grok login'."
          +agent-shell-grok-bin))

  ;; Avoid zoom thrashing the agent window (same idea as former grok-ide).
  (with-eval-after-load 'zoom
    (when (boundp 'zoom-ignored-major-modes)
      (add-to-list 'zoom-ignored-major-modes 'agent-shell-mode))))

(provide 'init-agent-shell)

;;; init-agent-shell.el ends here
