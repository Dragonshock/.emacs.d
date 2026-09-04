;;; -*- lexical-binding: t -*-
;;; init-agent-shell.el --- Grok Build + Claude Code + Pi + Cursor via agent-shell (ACP) -*- lexical-binding: t; -*-

;; ACP agents in agent-shell (Grok Build, Claude Code, Pi, Cursor).
;; UX aligned with agent-shell author (viewport-first) + package same-window
;; display (applied 2026-08-03: V1 D1a V3 from
;; dev-docs/notes/agent-shell-ux-align-recommendations-2026-08-02.md).
;; V4 (tool-use expand-by-default) reverted 2026-08-14: expanded tool
;; bodies + markdown tables fed a jit-lock 0-delay timer storm.
;; Table faces: package defaults (header bold, border comment, zebra
;; lazy-highlight).  Local C3 remaps and markdown `:align-to PIXEL'
;; were reverted 2026-08-25 (Invalid face 728 redisplay hang).
;;
;; Grok uses the OFFICIAL agent-shell-xai.el (upstream PR #720) — process
;; contract, welcome screen and auth all come from the package:
;;   command: grok agent stdio       (absolute path set below)
;;   auth:    ACP authenticate with `cached_token' (~/.grok/auth.json,
;;            written by `grok login'; no API key involved)
;;   model:   package default nil (CLI/session chooses; `C-c C-v' to switch).
;;            Do not pin ACP IDs.  README `-m grok-build' is a CLI alias,
;;            not an ACP model id; `--always-approve' is not used here.
;; Claude:  claude-agent-acp (npm: @agentclientprotocol/claude-agent-acp)
;;          — not the bare `claude' CLI; that is only for `claude login'.
;; Pi:      pi-acp adapter (npm: pi-acp) → spawns `pi --mode rpc'
;;          — agent-shell never talks to bare `pi' over ACP; see
;;          dev-docs/notes/how-agent-shell-works-with-pi-2026-08-02.md
;; Cursor:  official Cursor CLI ACP server (`agent acp'), not Cursor.app
;;          and not a bare `cursor' binary.  Auth is external (`agent
;;          login'); leave `agent-shell-cursor-authentication' at :none.
;;
;; MCP: package default `agent-shell-mcp-servers' is nil — each agent uses
;; its own native MCP/plugins (same idea as Zed agent-owned context servers).
;;
;; Keys: package has no global bind (README: M-x agent-shell).  Author
;; dotsies uses C-c C-w globally and in agent-shell / emacs-lisp maps.
;; Do not steal org-mode C-c C-w (org-refile).  In-buffer keys stay at
;; package defaults (RET send, C-c C-c interrupt, C-c C-v/m/t, C-c C-o).
;;   C-c C-w          start or reuse a shell; picker when creating a NEW one
;;   C-u C-c C-w      force a new shell (picker: Grok / Cursor / Claude / Pi)
;;   C-u C-u C-c C-w  pick among existing shells
;;   C-c C-v          set session model (when advertised)
;;   C-c C-m          set session mode
;;   C-c C-t          set thought level (when advertised)
;;   C-c C-s          set session config option (when advertised)
;;   C-<tab>          cycle session mode
;;   C-c C-o          switch viewport ↔ shell buffer
;;   Viewport view:   y / c / m / r (and ? for help)
;;   Compose:         M-x agent-shell-prompt-compose (prefer-viewport: C-c C-w)
;;   M-x +agent-shell-start-grok    always new Grok
;;   M-x +agent-shell-start-claude  always new Claude
;;   M-x +agent-shell-start-pi      always new Pi
;;   M-x +agent-shell-start-cursor  always new Cursor
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
;;   - Pi: `pi` + `pi-acp` on PATH (Homebrew/npm); absolute paths set below
;;   - Cursor: ~/.local/bin/agent + `agent login'

(eval-when-compile
  (require 'cl-lib))

;;; Paths

(defconst +agent-shell-grok-bin
  (expand-file-name "~/.grok/bin/grok")
  "Absolute path to the Grok Build CLI.
Same binary as `+telega-grok-bin' (init-social.el) uses for unread
summaries.")

(defconst +agent-shell-pi-acp-bin
  "/opt/homebrew/bin/pi-acp"
  "Absolute path to the pi-acp ACP adapter (not bare `pi').")

(defconst +agent-shell-pi-bin
  "/opt/homebrew/bin/pi"
  "Absolute path to the pi coding-agent CLI.
Passed to pi-acp as PI_ACP_PI_COMMAND so the adapter does not rely on PATH.")

(defconst +agent-shell-cursor-bin
  (expand-file-name "~/.local/bin/agent")
  "Absolute path to the Cursor CLI (`agent').
agent-shell uses the official ACP server: `agent acp'.  Not Cursor.app.")

(defconst +agent-shell-bin-dirs
  (list (file-name-directory +agent-shell-grok-bin)
        (file-name-directory +agent-shell-cursor-bin)
        "/opt/homebrew/bin"
        "/usr/local/bin")
  "Directories that may hold ACP agent CLIs (grok, claude-agent-acp, pi-acp, pi, agent).

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

(defun +agent-shell-xai-acp-command ()
  "Grok ACP argv for the current `default-directory'.

Local Emacs keeps the macOS absolute path.

A TRAMP buffer must NOT start `grok' via Tramp's file-handler
process: that goes through a login shell, so MOTD and
`tramp_exit_status' leak into ACP stdio and the session stays on
Initializing forever.  Use a local `ssh -T' instead; the remote
command is still `grok agent stdio' on the VPS."
  (if-let* ((remote (file-remote-p default-directory)))
      (let* ((host (file-remote-p default-directory 'host))
             (user (file-remote-p default-directory 'user))
             (target (if user (format "%s@%s" user host) host))
             (cwd (directory-file-name
                   (file-local-name (expand-file-name default-directory))))
             (remote-sh
              (format "cd %s && exec grok agent stdio"
                      (shell-quote-argument cwd))))
        (list "ssh" "-T" "-o" "BatchMode=yes" "-o" "RequestTTY=no"
              target remote-sh))
    (list +agent-shell-grok-bin "agent" "stdio")))

(defun +agent-shell-xai-make-client-around (orig &rest args)
  "Bind `agent-shell-xai-acp-command' to the cwd-appropriate grok."
  (let ((agent-shell-xai-acp-command (+agent-shell-xai-acp-command)))
    (apply orig args)))

(defun +acp-start-client-without-tramp-pty (orig &rest args)
  "Start ACP with a local process when the command is already `ssh -T'.

`acp--start-client' sets `:file-handler' from `default-directory'.
If that is still a TRAMP path, Emacs would try to run `ssh' *on*
the VPS.  Bind a local directory so the file-handler stays nil."
  (if (not (file-remote-p default-directory))
      (apply orig args)
    (let ((default-directory (expand-file-name "~/")))
      (apply orig args))))

(defun +agent-shell-reject-non-grok-remote (&rest args)
  "Remote ACP is Grok-only; refuse Claude / Pi / Cursor on TRAMP."
  (when-let* ((remote (file-remote-p default-directory))
              (config (plist-get args :config))
              (id (and (consp config) (map-elt config :identifier))))
    (unless (eq id 'grok-build)
      (user-error "Remote ACP supports Grok only (not %s). Cwd: %s"
                  id remote))))

(defun +agent-shell-require-local-acp (who)
  "Signal an error if starting non-Grok ACP agent WHO on a TRAMP cwd."
  (when (file-remote-p default-directory)
    (user-error
     "Remote ACP supports Grok only. Use M-x +agent-shell-start-grok (not %s)."
     who)))

(defun +agent-shell-transcript-file-path ()
  "Transcript path that is never a TRAMP file.

Default agent-shell writes `$cwd/.agent-shell/transcripts/*.md`.
When cwd is `/ssh:host:...`, every token `write-region's over
TRAMP (copy + base64 encode/decode) and the UI freezes."
  (let ((cwd (or (ignore-errors (agent-shell-cwd)) default-directory)))
    (if (not (file-remote-p cwd))
        (agent-shell--default-transcript-file-path)
      (let* ((root (no-littering-expand-var-file-name
                    "agent-shell-tramp/transcripts/"))
             (host (or (file-remote-p cwd 'host) "remote"))
             (dir (expand-file-name host root)))
        (make-directory dir t)
        (expand-file-name (format-time-string "%F-%H-%M-%S.md") dir)))))

;;; xAI ACP reverse-requests (plan approval / questionnaire)

;; Grok intercepts exit_plan_mode / ask_user_question and reverse-RPCs the
;; Emacs client.  agent-shell's default handler replies -32601, which Grok
;; surfaces as "client disconnected" and stays in plan mode.
;; Wire (Grok 1.0.4): methods "_x.ai/…" or "x.ai/…".
;;   exit_plan_mode result: {outcome: approved|abandoned|keep_planning, feedback}
;;   ask_user_question result: {outcome: accepted|cancelled, answers, annotations}

(defun +agent-shell-xai-json-get (obj key)
  "Get KEY from JSON alist OBJ (symbol or string key)."
  (when obj
    (or (map-elt obj key)
        (let ((name (if (symbolp key) (symbol-name key) key)))
          (or (map-elt obj name)
              (map-elt obj (intern name)))))))

(defun +agent-shell-xai-ext-kind (method)
  "Return `exit-plan-mode', `ask-user-question', or nil for METHOD."
  (when (stringp method)
    (let ((m (if (string-prefix-p "_" method) (substring method 1) method)))
      (cond
       ((or (equal m "x.ai/exit_plan_mode")
            (string-suffix-p "/exit_plan_mode" m))
        'exit-plan-mode)
       ((or (equal m "x.ai/ask_user_question")
            (string-suffix-p "/ask_user_question" m))
        'ask-user-question)))))

(defun +agent-shell-xai-send-result (state request-id result)
  "Reply to Grok reverse-request REQUEST-ID on STATE with RESULT alist."
  (acp-send-response
   :client (map-elt state :client)
   :response `((:request-id . ,request-id)
               (:result . ,result))))

(defun +agent-shell-xai-plan-file-candidates (state params)
  "Possible remote/local plan.md paths for this Grok session."
  (let* ((sid (or (+agent-shell-xai-json-get params 'sessionId)
                  (map-nested-elt state '(:session :id))))
         (cwd (or (ignore-errors (agent-shell-cwd)) default-directory))
         (local (directory-file-name
                 (file-local-name (expand-file-name cwd))))
         (sess-root (let ((default-directory cwd))
                      (expand-file-name "~/.grok/sessions/"))))
    (when sid
      (delq nil
            (list
             (expand-file-name
              (format "%s/%s/plan.md" (url-hexify-string local) sid)
              sess-root)
             (when (file-remote-p cwd)
               (expand-file-name
                (format "%s/%s/plan.md"
                        (url-hexify-string (directory-file-name cwd))
                        sid)
                sess-root)))))))

(defun +agent-shell-xai-read-plan-markdown (state params)
  "Plan body from PARAMS `planContent', or plan.md on disk."
  (or (let ((text (+agent-shell-xai-json-get params 'planContent)))
        (and (stringp text) (not (string-empty-p text)) text))
      (catch 'found
        (dolist (path (+agent-shell-xai-plan-file-candidates state params))
          (when (and path (file-readable-p path))
            (throw 'found
                   (with-temp-buffer
                     (insert-file-contents path)
                     (buffer-string)))))
        nil)
      "# No plan written yet\n"))

(defun +agent-shell-xai-show-plan (markdown)
  "Show MARKDOWN in *Grok Plan* so the minibuffer prompt stays usable."
  (let ((buf (get-buffer-create "*Grok Plan*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (or markdown "# No plan written yet\n"))
        (goto-char (point-min))
        (view-mode 1)))
    (display-buffer buf)))

(defun +agent-shell-xai-handle-exit-plan-mode (state acp-request)
  "Approve / revise / abandon Grok plan mode for ACP-REQUEST."
  (let* ((id (+agent-shell-xai-json-get acp-request 'id))
         (params (+agent-shell-xai-json-get acp-request 'params))
         (plan (+agent-shell-xai-read-plan-markdown state params)))
    (when (fboundp 'agent-shell--update-fragment)
      (ignore-errors
        (agent-shell--update-fragment
         :state state
         :block-id "xai-exit-plan-mode"
         :label-left (propertize "Grok plan"
                                 'font-lock-face 'agent-shell-section-heading)
         :body plan
         :expanded t
         :above-last-prompt t)))
    (+agent-shell-xai-show-plan plan)
    (condition-case nil
        (let* ((choice (car (read-multiple-choice
                             "Grok 计划审批: "
                             '((?a "批准" "退出 plan mode 并开始改文件")
                               (?s "改计划" "留在 plan mode，可附修改意见")
                               (?q "放弃" "丢掉计划并退出 plan mode")))))
               (feedback (if (eq choice ?s)
                             (read-string "修改意见（可空）: ")
                           ""))
               (outcome (pcase choice
                          (?a "approved")
                          (?q "abandoned")
                          (_ "keep_planning"))))
          (+agent-shell-xai-send-result
           state id
           `((outcome . ,outcome)
             (feedback . ,(or feedback "")))))
      (quit
       (+agent-shell-xai-send-result
        state id
        '((outcome . "keep_planning")
          (feedback . "")))))))

(defun +agent-shell-xai-normalize-questions (params)
  "Return a list of question alists from ask_user_question PARAMS."
  (let ((qs (+agent-shell-xai-json-get params 'questions)))
    (cond
     ((vectorp qs) (append qs nil))
     ((listp qs) qs)
     ((+agent-shell-xai-json-get params 'question)
      (list params))
     (t nil))))

(defun +agent-shell-xai-option-label (option)
  "Label string for one ask_user_question OPTION."
  (or (and (stringp option) option)
      (+agent-shell-xai-json-get option 'label)
      (format "%s" option)))

(defun +agent-shell-xai-ask-one-question (question)
  "Prompt for one QUESTION alist; return chosen label string."
  (let* ((text (or (+agent-shell-xai-json-get question 'question)
                   "Question"))
         (options (let ((raw (+agent-shell-xai-json-get question 'options)))
                    (cond ((vectorp raw) (append raw nil))
                          ((listp raw) raw)
                          (t nil))))
         (labels (mapcar #'+agent-shell-xai-option-label options))
         (multi (+agent-shell-xai-json-get question 'multiSelect))
         (help (mapconcat
                (lambda (o)
                  (format "  %s — %s"
                          (+agent-shell-xai-option-label o)
                          (or (+agent-shell-xai-json-get o 'description) "")))
                options
                "\n")))
    (if (null labels)
        (read-string (format "%s\n(自由作答): " text))
      (if multi
          (string-join
           (completing-read-multiple
            (format "%s\n%s\n可多选（逗号分隔）: " text help)
            labels nil t)
           ", ")
        (completing-read (format "%s\n%s\n选择: " text help)
                         labels nil t)))))

(defun +agent-shell-xai-handle-ask-user-question (state acp-request)
  "Answer Grok ask_user_question for ACP-REQUEST via the minibuffer."
  (let* ((id (+agent-shell-xai-json-get acp-request 'id))
         (params (+agent-shell-xai-json-get acp-request 'params))
         (questions (+agent-shell-xai-normalize-questions params)))
    (condition-case nil
        (if (null questions)
            (+agent-shell-xai-send-result
             state id '((outcome . "cancelled")))
          (let ((answers (make-hash-table :test 'equal))
                (annotations (make-hash-table :test 'equal)))
            (dolist (q questions)
              (let ((text (or (+agent-shell-xai-json-get q 'question)
                              "Question")))
                (puthash text (+agent-shell-xai-ask-one-question q) answers)))
            (+agent-shell-xai-send-result
             state id
             `((outcome . "accepted")
               (answers . ,answers)
               (annotations . ,annotations)))))
      (quit
       (+agent-shell-xai-send-result
        state id '((outcome . "cancelled")))))))

(defun +agent-shell-xai-on-request (orig &rest args)
  "Handle Grok `_x.ai/*' reverse-requests; otherwise call ORIG."
  (let* ((acp-request (plist-get args :acp-request))
         (state (plist-get args :state))
         (kind (+agent-shell-xai-ext-kind
                (or (map-elt acp-request 'method)
                    (+agent-shell-xai-json-get acp-request 'method)))))
    (pcase kind
      ('exit-plan-mode
       (+agent-shell-xai-handle-exit-plan-mode state acp-request))
      ('ask-user-question
       (+agent-shell-xai-handle-ask-user-question state acp-request))
      (_ (apply orig args)))))

;;; Entry commands (always force a NEW shell; DWIM reuse is on C-c C-w)

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
  (+agent-shell-require-local-acp "Claude")
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
  (+agent-shell-require-local-acp "Pi")
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

(defun +agent-shell-start-cursor ()
  "Start a new interactive Cursor agent shell (ACP).

Requires the Cursor CLI `agent' (not Cursor.app) and a prior
`agent login' outside Emacs.  Authentication stays at the package
default `:none'."
  (interactive)
  (+agent-shell-require-local-acp "Cursor")
  (require 'agent-shell)
  (require 'agent-shell-cursor)
  (+agent-shell-ensure-path)
  (unless (file-executable-p +agent-shell-cursor-bin)
    (user-error
     "Cannot find Cursor CLI at %s. See https://cursor.com/docs/cli"
     +agent-shell-cursor-bin))
  (agent-shell--dwim :config (agent-shell-cursor-make-agent-config)
                     :new-shell t))

;;; Package setup

(use-package agent-shell
  :straight t
  ;; Autoload only library entry points; +agent-shell-start-* are defined
  ;; in this file when init loads it (do not map them to the agent-shell feature).
  :commands (agent-shell agent-shell-anthropic-start-claude-code
                         agent-shell-xai-start-grok
                         agent-shell-pi-start-agent
                         agent-shell-cursor-start-agent
                         agent-shell-prompt-compose)
  :bind (("C-c g a" . agent-shell)
         ("C-c g p" . agent-shell-prompt-compose)
         ("C-c g w" . agent-shell-send-dwim)
         :map agent-shell-mode-map
         ("M-<return>" . agent-shell-newline)
         ("C-c C-h" . agent-shell-help-menu)
         ("C-c C-q" . agent-shell-prompt-queue)
         ("C-c C-e" . agent-shell-prompt-steer))
  :custom-face
  (agent-shell-section-heading ((t (t (:inherit font-lock-function-name-face :height 0.9)))))
  (agent-shell-section-annotation ((t (:inherit shadow :height 0.8))))
  :preface
  (defun +agent-shell-dot-subdir (subdir)
    "Return the centralized Agent Shell data directory for SUBDIR."
    (let* ((cwd (directory-file-name (agent-shell-cwd)))
           (name (file-name-nondirectory cwd))
           (slug (replace-regexp-in-string
                  "[^[:alnum:]._-]+" "-" (if (string-empty-p name) "root" name)))
           (project-key
            (format "%s-%s" slug (substring (secure-hash 'sha1 cwd) 0 10))))
      (expand-file-name
       (file-name-concat project-key ".agent-shell" subdir)
       (locate-user-emacs-file "var/agent-shell/"))))
  :config
  (+agent-shell-ensure-path)
  ;; Official Grok Build support (agent-shell-xai.el, upstream PR #720).
  (require 'agent-shell-xai)
  (require 'agent-shell-pi)
  (require 'agent-shell-cursor)

  ;; Official argv is `grok agent stdio' (agent-shell-xai.el / README).
  ;; Absolute path is load-bearing for GUI/daemon PATH; do not drop for the
  ;; PATH-only default.  inherit-env is the README-documented way to pass
  ;; HOME/PATH so `grok' can read ~/.grok/auth.json.  Model id stays at the
  ;; package default nil (CLI/session chooses).
  (setq agent-shell-xai-acp-command
        (list +agent-shell-grok-bin "agent" "stdio")
        agent-shell-xai-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; Pi: ACP adapter + pin pi binary for the adapter (daemon-safe).
  (setq agent-shell-pi-acp-command (list +agent-shell-pi-acp-bin)
        agent-shell-pi-environment
        (agent-shell-make-environment-variables
         "PI_ACP_PI_COMMAND" +agent-shell-pi-bin
         :inherit-env t))

  ;; Cursor: official `agent acp' + inherit login env (HOME / auth files).
  (setq agent-shell-cursor-acp-command (list +agent-shell-cursor-bin "acp")
        agent-shell-cursor-environment
        (agent-shell-make-environment-variables :inherit-env t))

  ;; Picker: README lets you narrow `agent-shell-agent-configs'.
  ;; Official skip-picker form is a bare symbol (`'grok-build'); the
  ;; documented `(preselect . id)' form still shows the picker.
  ;; Viewport: README optional (`setopt agent-shell-prefer-viewport-interaction t').
  ;; display-action / session-strategy / mcp-servers stay at package defaults
  ;; (same-window, prompt, nil).  inhibit-system-sleep: README "turn it off"
  ;; — ns-block-system-sleep SIGSEGV on this machine (2026-08-14).
  (setq agent-shell-agent-configs
        (list #'agent-shell-xai-make-grok-config
              #'agent-shell-cursor-make-agent-config
              #'agent-shell-anthropic-make-claude-code-config
              #'agent-shell-pi-make-agent-config)
        agent-shell-preferred-agent-config '(preselect . grok-build)
        agent-shell-prefer-viewport-interaction t
        agent-shell-inhibit-system-sleep nil
        agent-shell-tool-use-expand-by-default nil
        agent-shell-thought-process-expand-by-default nil
        agent-shell-dot-subdir-function #'+agent-shell-dot-subdir
        agent-shell-show-context-usage-indicator 'detailed
        agent-shell-file-display-action '((display-buffer-reuse-window display-buffer-pop-up-window)))

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

  (unless (executable-find "claude-agent-acp")
    (warn "Cannot find claude-agent-acp. Install: npm i -g @agentclientprotocol/claude-agent-acp (then `claude login')."))

  (unless (file-executable-p +agent-shell-pi-acp-bin)
    (warn "Cannot find pi-acp at %s. Install: npm i -g pi-acp" +agent-shell-pi-acp-bin))

  (unless (file-executable-p +agent-shell-pi-bin)
    (warn "Cannot find pi at %s. Install: npm i -g @earendil-works/pi-coding-agent"
          +agent-shell-pi-bin))

  (unless (or (file-executable-p +agent-shell-cursor-bin)
              (executable-find "agent"))
    (warn "Cannot find Cursor CLI at %s. Install from https://cursor.com/docs/cli then run `agent login'."
          +agent-shell-cursor-bin))

  ;; Avoid zoom thrashing the agent window (same idea as former grok-ide).
  (with-eval-after-load 'zoom
    (when (boundp 'zoom-ignored-major-modes)
      (add-to-list 'zoom-ignored-major-modes 'agent-shell-mode)))

  (advice-add 'agent-shell-xai-make-client :around
              #'+agent-shell-xai-make-client-around)
  (advice-add 'acp--start-client :around
              #'+acp-start-client-without-tramp-pty)
  (advice-add 'agent-shell--start :before
              #'+agent-shell-reject-non-grok-remote)
  (advice-add 'agent-shell--on-request :around
              #'+agent-shell-xai-on-request)

  ;; Never write transcripts over TRAMP (see +agent-shell-transcript-file-path).
  (setq agent-shell-transcript-file-path-function
        #'+agent-shell-transcript-file-path)
  (require 'agent-shell-tramp nil t)
  (when (fboundp 'agent-shell-tramp-mode)
    (setq agent-shell-tramp-transcript-directory
          (no-littering-expand-var-file-name "agent-shell-tramp/transcripts/"))
    (make-directory agent-shell-tramp-transcript-directory t)
    (agent-shell-tramp-mode 1)
    ;; Keep our tramp-safe path function (mode would overwrite it).
    (setq agent-shell-transcript-file-path-function
          #'+agent-shell-transcript-file-path)))

;; TRAMP: start ACP on the remote via acp.el :file-handler, map paths.
;; Remote ACP is Grok-only (T2); this package is the path resolver.
(use-package agent-shell-tramp
  :straight (:host github :repo "junyi-hou/agent-shell-tramp")
  :after agent-shell
  :config
  (setq agent-shell-tramp-transcript-directory
        (no-littering-expand-var-file-name "agent-shell-tramp/transcripts/"))
  (make-directory agent-shell-tramp-transcript-directory t)
  (agent-shell-tramp-mode 1))

(provide 'init-agent-shell)

;;; init-agent-shell.el ends here
