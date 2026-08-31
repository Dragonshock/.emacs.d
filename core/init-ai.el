;;; -*- lexical-binding: t -*-

(use-package gptel
  :straight t
  :init
  (setq gptel-model 'deepseek-v4-flash
        gptel-default-mode 'org-mode
        ;; Confirm tools when they request it (gptel-agent Bash/Eval/Write/Edit).
        ;; Was nil (= never); default 'auto is safer with agent tools loaded.
        gptel-confirm-tool-calls 'auto)
  :config
  (setq-default gptel-backend
                (gptel-make-deepseek "DeepSeek-thinking"
                  :stream t
                  :request-params '(:thinking (:type "enabled"))
                  :key #'gptel-api-key-from-auth-source))
  (add-hook! gptel-post-stream-hook #'gptel-auto-scroll)
  (add-hook! gptel-post-response-functions #'gptel-end-of-response))

(use-package gptel-rewrite
  :straight nil
  :bind (("C-c r t" . +gptel-rewrite-translate-to-chinese)
         ("C-c r s" . +gptel-rewrite-summarize)
         :map gptel-rewrite-actions-map
         ("C-c C-x" . +gptel-rewrite-export))
  :preface
  (defun +gptel-rewrite-export (&optional overlays)
    "Export OVERLAYS to a new buffer without changing their source.
When OVERLAYS is nil, export all pending rewrites in the current buffer."
    (interactive)
    (require 'gptel-rewrite)
    (setq overlays (or overlays gptel--rewrite-overlays))
    (unless overlays
      (user-error "No pending rewrites to export"))
    (let* ((source-buffer (current-buffer))
           (source-name (buffer-name source-buffer))
           (prepared-buffer
            (gptel--rewrite-prepare-buffer overlays))
           (prepared-point
            (with-current-buffer prepared-buffer
              (- (point) (point-min))))
           (contents
            (with-current-buffer prepared-buffer
              (buffer-substring-no-properties (point-min) (point-max))))
           (export-buffer
            (generate-new-buffer
             (format "*gptel rewrite export: %s*" source-name))))
      (with-current-buffer export-buffer
        (markdown-ts-mode)
        (insert contents)
        (goto-char (+ (point-min)
                      (min prepared-point (- (point-max) (point-min)))))
        (setq-local header-line-format
                    (format " Exported rewrite from %s" source-name))
        (visual-line-mode 1)
        (set-buffer-modified-p nil))
      (pop-to-buffer export-buffer)))

  (defun +gptel-rewrite-region-or-buffer (prompt)
    "Rewrite the active region, or the whole buffer, according to PROMPT."
    (require 'gptel-rewrite)
    (if (use-region-p)
        (gptel--suffix-rewrite prompt)
      (when (= (point-min) (point-max))
        (user-error "Buffer is empty"))
      (save-mark-and-excursion
        (set-mark (point-max))
        (goto-char (point-min))
        (activate-mark)
        (gptel--suffix-rewrite prompt))))

  (defun +gptel-rewrite-translate-to-chinese ()
    "Translate the active region, or the whole buffer, to Chinese."
    (interactive)
    (+gptel-rewrite-region-or-buffer
     "Translate into fluent Chinese."))

  (defun +gptel-rewrite-summarize ()
    "Summarize the active region, or the whole buffer when no region is active."
    (interactive)
    (+gptel-rewrite-region-or-buffer
     "Summarize in Chinese while preserving details and key information."))

  (with-eval-after-load 'embark
    (keymap-set embark-region-map "T" #'+gptel-rewrite-translate-to-chinese)
    (keymap-set embark-region-map "S" #'+gptel-rewrite-summarize)))

(use-package gptel-agent
  :straight t
  :after gptel
  :config (gptel-agent-update))


(use-package gptel-magit
  :straight (gptel-magit :type git :host github :repo "roife/gptel-magit")
  :hook ((magit-mode . gptel-magit-install))
  :config
  ;; Default prompt is already Conventional Commits in gptel-magit.
  (setq gptel-magit-body-length 72))

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

(use-package codex-ide
  :straight (:type git :host github :repo "dgillis/emacs-codex-ide")
  :custom-face
  (codex-ide-item-summary-face ((t (:inherit font-lock-function-name-face :height 0.9))))
  (codex-ide-item-detail-face ((t (:inherit shadow :height 0.8))))
  :init
  (setq codex-ide-diff-inline-fold-threshold 20
        codex-ide-image-detail "auto"
        codex-ide-prompt-placeholder-text ""
        codex-ide-placeholder-ellipsis-animation-interval nil
        codex-ide-status-mode-auto-refresh-delay 0.3
        codex-ide-want-mcp-bridge nil
        codex-ide-emacs-context-policy nil
        codex-ide-session-transcript-default-detail-level 'compact
        codex-ide-buffer-name-function (lambda (dir)
                                         (format "%s: %s"
                                                 codex-ide-buffer-name-prefix
                                                 (file-name-nondirectory (directory-file-name dir)))))
  )

(use-package codex-ide-session
  :straight nil
  :preface
  (defun +codex-ide-submit-or-newline ()
    "Submit one-line Codex prompts, otherwise insert a newline."
    (interactive)
    (let* ((session (codex-ide--get-default-session-for-current-buffer))
           (start (and session
                       (codex-ide-session-input-start-marker session)))
           (end (and session
                     (codex-ide--input-end-position session))))
      (if (and (markerp start)
               end
               (not (save-excursion
                      (goto-char (marker-position start))
                      (search-forward "\n" end t))))
          (codex-ide-submit)
        (newline))))
  :bind (:map codex-ide-session-prompt-minor-mode-map
              ("RET" . +codex-ide-submit-or-newline)
              ("<return>" . +codex-ide-submit-or-newline)
              ("S-<return>" . newline)
              :map codex-ide-session-mode-map
              ("C-c C-;" . codex-ide-agent-config-menu)
              ("C-c C-r" . codex-ide-status))
  :config
  (require 'codex-ide))


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
