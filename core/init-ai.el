;;; -*- lexical-binding: t -*-

(use-package gptel
  :straight t
  :init
  ;; README: default backend via gptel-make-deepseek; key from ~/.authinfo
  ;; (machine api.deepseek.com login apikey …).  Model ids are the package's
  ;; current DeepSeek catalog (v4-flash / v4-pro), not the older reasoner id.
  (setq gptel-model 'deepseek-v4-flash
        gptel-default-mode 'org-mode
        gptel-confirm-tool-calls 'auto)
  :config
  (setq gptel-backend
        (gptel-make-deepseek "DeepSeek"
          :stream t
          :key gptel-api-key
          :request-params '(:thinking (:type "enabled"))))
  (add-hook! gptel-post-stream-hook #'gptel-auto-scroll)
  (add-hook! gptel-post-response-functions #'gptel-end-of-response))


(use-package gptel-agent
  :straight t
  :after gptel
  :config (gptel-agent-update))


(use-package gptel-magit
  :straight (gptel-magit :type git :host github :repo "roife/gptel-magit")
  :hook ((magit-mode . gptel-magit-install))
  :config
  (setq gptel-magit-body-length 72
        gptel-magit-commit-prompt (cdr (assoc "Conventional Commits" gptel-magit-commit-styles-alist)))

  (defun +gptel-magit-fish (fifo insertp)
    "Generate a message, optionally insert it, and report through FIFO."
    (let ((commit-buffer (magit-commit-message-buffer))
          record fsm)
      (cond
       ((and insertp (not commit-buffer))
        (user-error "No commit in progress"))
       ((and (not insertp) commit-buffer)
        (user-error "Commit already in progress")))
      (setq fsm
            (gptel-magit--generate
             (lambda (message)
               (setq record (concat "0" message)))
             nil commit-buffer "Generating commit message..."))
      (let ((info (gptel-fsm-info fsm)))
        (plist-put
         info :post
         (append
          (plist-get info :post)
          (list
           (lambda (request-info)
             (with-temp-buffer
               (insert
                (or record
                    (if (eq (gptel-fsm-state fsm) 'DONE)
                        "0"
                      (concat "1" (format "%s"
                                          (or (plist-get request-info :status)
                                              (plist-get request-info :error)
                                              "generation failed"))))))
               (write-region (point-min) (point-max)
                             fifo nil 'silent)))))))
      fsm)))

(use-package gptel-quick
  :straight (gptel-quick :type git :host github :repo "roife/gptel-quick")
  :bind (("C-c g e" . +gptel-quick-explain)
         ("C-c g t" . +gptel-quick-translate-to-chinese)
         ("C-c g s" . +gptel-quick-summarize)
         ("C-c g d" . +gptel-quick-dict))
  :preface
  (defun +gptel-quick-region-or-buffer (system-message &optional limit-response thing)
    "Run `gptel-quick' on THING, the active region, or the buffer.
Preserve SYSTEM-MESSAGE when requesting another response with `+'.  When
LIMIT-RESPONSE is non-nil, apply gptel-quick's count-derived token limit."
    (require 'gptel-quick)
    (let ((query-text
           (if thing
               (or (thing-at-point thing t)
                   (user-error "No %s at point" thing))
             (if (use-region-p)
                 (buffer-substring-no-properties (region-beginning) (region-end))
               (buffer-substring-no-properties (point-min) (point-max))))))
      (when (string-empty-p query-text)
        (user-error "Buffer is empty"))
      (gptel-quick query-text nil
                   (append (list :system system-message)
                           (unless limit-response
                             (list :max-tokens nil))))))

  (defmacro +gptel-quick-define-command (name doc prompt &optional limit thing)
    "Define NAME as a gptel-quick action over the region or buffer."
    `(defun ,name ()
       ,doc (interactive)
       (+gptel-quick-region-or-buffer ,prompt ,limit ,thing)))

  (+gptel-quick-define-command +gptel-quick-explain
                               "Explain the active region, or the whole buffer, in Chinese."
                               "Explain in clear Chinese, preserving necessary context and details." t)

  (+gptel-quick-define-command +gptel-quick-translate-to-chinese
                               "Translate the active region, or the whole buffer, to Chinese."
                               "Translate into fluent Chinese.")

  (+gptel-quick-define-command +gptel-quick-summarize
                               "Summarize the active region, or the whole buffer, in Chinese."
                               "Summarize in Chinese while preserving details and key information." t)

  (+gptel-quick-define-command +gptel-quick-dict
                               "Explain the word at point in dictionary style."
                               "Given a word, explain it in the style of a concise English dictionary entry,
and add accurate Chinese translations for each sense. Preserve the compact dictionary
format in plain text rather than giving a long explanatory article or markdown document.
No need for chinese in sentences.

Use this format:
*word* syllable division | pronunciation | part of speech (inflections)

1. English definition **中文**
     *Example sentence.*
 | Sub-sense or extended meaning **中文**
     *Example sentence.*
• ...
2. English definition **中文**
     *Example sentence.*"
                               nil 'word)

  (with-eval-after-load 'embark
    (keymap-set embark-general-map "?" #'gptel-quick)
    (keymap-set embark-region-map "E" #'+gptel-quick-explain)
    (keymap-set embark-region-map "T" #'+gptel-quick-translate-to-chinese)
    (keymap-set embark-region-map "S" #'+gptel-quick-summarize)
    (keymap-set embark-region-map "D" #'+gptel-quick-dict))

  :config
  (setq gptel-quick-word-count 50
        gptel-quick-timeout nil))

(use-package agent-shell
  :straight (:type git :host github :repo "xenodium/agent-shell")
  :bind (("C-c g a" . agent-shell)
         ("C-c g p" . agent-shell-prompt-compose)
         ("C-c g w" . agent-shell-send-dwim)
         :map agent-shell-mode-map
         ("M-<return>" . agent-shell-newline)
         ("C-c C-h" . agent-shell-help-menu)
         ("C-c C-q" . agent-shell-prompt-queue)
         ("C-c C-e" . agent-shell-prompt-steer))
  :custom-face
  (agent-shell-section-heading ((t (:inherit font-lock-function-name-face :height 0.9))))
  (agent-shell-section-annotation ((t (:inherit shadow :height 0.8))))
  :preface
  (defconst +agent-shell-grok-bin
    (expand-file-name "~/.grok/bin/grok")
    "Absolute path to the Grok Build CLI.")
  (defconst +agent-shell-pi-acp-bin
    "/opt/homebrew/bin/pi-acp"
    "Absolute path to the pi-acp ACP adapter (not bare `pi').")
  (defconst +agent-shell-pi-bin
    "/opt/homebrew/bin/pi"
    "Absolute path to the pi CLI, passed to pi-acp as PI_ACP_PI_COMMAND.")
  (defconst +agent-shell-cursor-bin
    (expand-file-name "~/.local/bin/agent")
    "Absolute path to the Cursor CLI (`agent acp'), not Cursor.app.")
  (defconst +agent-shell-bin-dirs
    (list (file-name-directory +agent-shell-grok-bin)
          (file-name-directory +agent-shell-cursor-bin)
          "/opt/homebrew/bin"
          "/usr/local/bin")
    "Directories that may hold ACP agent CLIs.")

  (defun +agent-shell-ensure-path ()
    "Ensure ACP agent CLI directories are on `exec-path' and process PATH."
    (dolist (dir +agent-shell-bin-dirs)
      (when (file-directory-p dir)
        (add-to-list 'exec-path dir)
        (let ((path (getenv "PATH")))
          (unless (and path (string-match-p (regexp-quote dir) path))
            (setenv "PATH" (concat dir path-separator (or path ""))))))))

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

  (defun +agent-shell-xai-acp-command ()
    "Grok ACP argv for the current `default-directory'.
Remote buffers use local `ssh -T' so TRAMP login-shell MOTD cannot leak
into ACP stdio (that leaves the session on Initializing)."
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
    "Start ACP locally when the command is already `ssh -T'."
    (if (not (file-remote-p default-directory))
        (apply orig args)
      (let ((default-directory (expand-file-name "~/")))
        (apply orig args))))

  (defun +agent-shell-reject-non-grok-remote (&rest args)
    "Remote ACP is Grok-only; refuse Claude / Pi / Cursor / Codex on TRAMP."
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
    "Transcript path that is never a TRAMP file."
    (let ((cwd (or (ignore-errors (agent-shell-cwd)) default-directory)))
      (if (not (file-remote-p cwd))
          (agent-shell--default-transcript-file-path)
        (let* ((root (no-littering-expand-var-file-name
                      "agent-shell-tramp/transcripts/"))
               (host (or (file-remote-p cwd 'host) "remote"))
               (dir (expand-file-name host root)))
          (make-directory dir t)
          (expand-file-name (format-time-string "%F-%H-%M-%S.md") dir)))))

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

  (defun +agent-shell-start-grok ()
    "Start a new interactive Grok Build agent shell."
    (interactive)
    (require 'agent-shell)
    (require 'agent-shell-xai)
    (+agent-shell-ensure-path)
    (agent-shell--dwim :config (agent-shell-xai-make-grok-config)
                       :new-shell t))

  (defun +agent-shell-start-claude ()
    "Start a new interactive Claude Code agent shell (ACP)."
    (interactive)
    (+agent-shell-require-local-acp "Claude")
    (require 'agent-shell)
    (require 'agent-shell-anthropic)
    (+agent-shell-ensure-path)
    (unless (executable-find "claude-agent-acp")
      (user-error
       "Cannot find claude-agent-acp. Install: npm i -g @agentclientprotocol/claude-agent-acp"))
    (agent-shell--dwim :config (agent-shell-anthropic-make-claude-code-config)
                       :new-shell t))

  (defun +agent-shell-start-pi ()
    "Start a new interactive Pi coding agent shell via pi-acp."
    (interactive)
    (+agent-shell-require-local-acp "Pi")
    (require 'agent-shell)
    (require 'agent-shell-pi)
    (+agent-shell-ensure-path)
    (unless (file-executable-p +agent-shell-pi-acp-bin)
      (user-error "Cannot find pi-acp at %s" +agent-shell-pi-acp-bin))
    (unless (file-executable-p +agent-shell-pi-bin)
      (user-error "Cannot find pi at %s" +agent-shell-pi-bin))
    (agent-shell--dwim :config (agent-shell-pi-make-agent-config)
                       :new-shell t))

  (defun +agent-shell-start-cursor ()
    "Start a new interactive Cursor agent shell (`agent acp')."
    (interactive)
    (+agent-shell-require-local-acp "Cursor")
    (require 'agent-shell)
    (require 'agent-shell-cursor)
    (+agent-shell-ensure-path)
    (unless (file-executable-p +agent-shell-cursor-bin)
      (user-error "Cannot find Cursor CLI at %s" +agent-shell-cursor-bin))
    (agent-shell--dwim :config (agent-shell-cursor-make-agent-config)
                       :new-shell t))

  (defun +agent-shell-force-graphic-header ()
    "Prefer graphical agent-shell header when a GUI frame is available."
    (when (display-graphic-p)
      (setq agent-shell-header-style 'graphical)))
  :init
  (setq agent-shell-openai-codex-acp-command '("mise" "exec" "--" "codex-acp")
        agent-shell-context-sources nil
        agent-shell-mcp-servers nil
        agent-shell-session-strategy 'prompt
        agent-shell-session-restore-verbosity 'full
        agent-shell-show-welcome-message nil
        agent-shell-activity-group-expand-by-default 'latest
        agent-shell-prefer-viewport-interaction t
        agent-shell-inhibit-system-sleep nil
        agent-shell-tool-use-expand-by-default nil
        agent-shell-thought-process-expand-by-default nil
        agent-shell-dot-subdir-function #'+agent-shell-dot-subdir
        agent-shell-show-context-usage-indicator 'detailed
        agent-shell-file-display-action '((display-buffer-reuse-window display-buffer-pop-up-window)))
  :config
  (+agent-shell-ensure-path)
  (require 'agent-shell-xai)
  (require 'agent-shell-pi)
  (require 'agent-shell-cursor)
  (setq agent-shell-xai-acp-command
        (list +agent-shell-grok-bin "agent" "stdio")
        agent-shell-xai-environment
        (agent-shell-make-environment-variables :inherit-env t)
        agent-shell-pi-acp-command (list +agent-shell-pi-acp-bin)
        agent-shell-pi-environment
        (agent-shell-make-environment-variables
         "PI_ACP_PI_COMMAND" +agent-shell-pi-bin
         :inherit-env t)
        agent-shell-cursor-acp-command (list +agent-shell-cursor-bin "acp")
        agent-shell-cursor-environment
        (agent-shell-make-environment-variables :inherit-env t)
        agent-shell-agent-configs
        (list #'agent-shell-xai-make-grok-config
              #'agent-shell-openai-make-codex-config
              #'agent-shell-cursor-make-agent-config
              #'agent-shell-anthropic-make-claude-code-config
              #'agent-shell-pi-make-agent-config)
        agent-shell-preferred-agent-config '(preselect . grok-build))
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
    (warn "Cannot find claude-agent-acp. Install: npm i -g @agentclientprotocol/claude-agent-acp"))
  (unless (file-executable-p +agent-shell-pi-acp-bin)
    (warn "Cannot find pi-acp at %s" +agent-shell-pi-acp-bin))
  (unless (or (file-executable-p +agent-shell-cursor-bin)
              (executable-find "agent"))
    (warn "Cannot find Cursor CLI at %s" +agent-shell-cursor-bin))
  (with-eval-after-load 'zoom
    (when (boundp 'zoom-ignored-major-modes)
      (add-to-list 'zoom-ignored-major-modes 'agent-shell-mode)))
  (advice-add #'agent-shell--update-bootstrapping-fragment :override #'ignore)
  (advice-add 'agent-shell-xai-make-client :around
              #'+agent-shell-xai-make-client-around)
  (advice-add 'acp--start-client :around
              #'+acp-start-client-without-tramp-pty)
  (advice-add 'agent-shell--start :before
              #'+agent-shell-reject-non-grok-remote)
  (advice-add 'agent-shell--on-request :around
              #'+agent-shell-xai-on-request)
  (setq agent-shell-transcript-file-path-function
        #'+agent-shell-transcript-file-path))

(use-package agent-shell-tramp
  :straight (:type git :host github :repo "junyi-hou/agent-shell-tramp")
  :after agent-shell
  :init
  (setq agent-shell-tramp-transcript-directory
        (no-littering-expand-var-file-name "agent-shell-tramp/transcripts/"))
  (make-directory agent-shell-tramp-transcript-directory t)
  :config
  (agent-shell-tramp-mode 1)
  ;; Mode overwrites the path function; keep tramp-safe local transcripts.
  (setq agent-shell-transcript-file-path-function
        #'+agent-shell-transcript-file-path))

(use-package agent-shell-attention
  :straight (:type git :host github :repo "ultronozm/agent-shell-attention.el")
  :commands agent-shell-attention-mode
  :hook (agent-shell-mode . +agent-shell-attention-enable)
  :bind (("C-c g j" . agent-shell-attention-jump)
         ("C-c g l" . agent-shell-attention-dashboard))
  :preface
  (defun +agent-shell-attention-enable ()
    "Enable global Agent Shell attention tracking on first use."
    (unless (bound-and-true-p agent-shell-attention-mode)
      (agent-shell-attention-mode 1)))
  :init
  (setq agent-shell-attention-render-function 'agent-shell-attention-render-active
        agent-shell-attention-show-zeros nil
        agent-shell-attention-notify-function nil))

(use-package agent-recall
  :straight (:type git :host github :repo "mrx-xo/agent-recall")
  :hook (agent-shell-mode . agent-recall-track-sessions)
  :bind (("C-c g h" . agent-recall-browse)
         ("C-c g u" . agent-recall-resume))
  :init
  (setq agent-recall-search-paths
        (mapcar #'expand-file-name
                '("~/.emacs.d" "~/code" "~/.config" "~/.emacs.d/var/agent-shell"))
        agent-recall-max-depth 3
        agent-recall-search-function 'consult-ripgrep
        agent-recall-browse-sort 'modified-desc
        agent-recall-resume-continue-transcript t))

(use-package agent-recall-consult
  :straight nil
  :bind ("C-c g /" . agent-recall-consult-search)
  :init
  (setq agent-recall-consult-resumable-only nil))

(use-package agent-review
  :straight (:type git :host github :repo "nineluj/agent-review")
  :commands agent-review
  :bind ("C-c g r" . +agent-review-codex)
  :preface
  (defun +agent-review-codex ()
    "Review staged and unstaged Git changes with Codex."
    (interactive)
    (require 'agent-review)
    (agent-review (agent-shell-openai-make-codex-config))))


;; [gptel-copilot] gptel-powered inline code completion
(use-package gptel-copilot
  :straight (:type git :host github :repo "roife/gptel-copilot")
  :commands gptel-copilot-mode
  :preface
  (defun +gptel-copilot-complete ()
    "Accept the completion, or move to the end of code or line."
    (interactive)
    (or (gptel-copilot-accept-completion)
        (mwim-end-of-code-or-line)))

  (defun +gptel-copilot-complete-word ()
    "Accept one completion word, or move forward one word."
    (interactive)
    (or (gptel-copilot-accept-completion-by-word 1)
        (forward-word)))

  :hook (prog-mode . gptel-copilot-mode)
  :bind (:map gptel-copilot-mode-map
              ("C-e" . +gptel-copilot-complete)
              ("M-f" . +gptel-copilot-complete-word))
  :config
  (require 'gptel-openai-oauth)

  (setq gptel-copilot-model 'gpt-5.4-mini
        gptel-copilot-backend
        (gptel-make-openai-oauth "OpenAI OAuth Inline"
          :request-params '(:reasoning (:effort "low")))))
