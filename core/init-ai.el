;;; -*- lexical-binding: t -*-

(use-package gptel
  :straight t
  :commands (gptel-api-key-from-auth-source
             +gptel-rewrite-translate-to-chinese)
  :bind (("C-c r t" . +gptel-rewrite-translate-to-chinese))
  :preface
  (defun +gptel-rewrite-translate-to-chinese (_beg _end)
    "Translate the active region to Chinese with `gptel-rewrite'."
    (interactive "r")
    (unless (use-region-p)
      (user-error "Select a region to translate"))
    (require 'gptel-rewrite)
    (gptel--suffix-rewrite "Translate into fluent Simplified Chinese."))
  :init
  (setq gptel-model 'deepseek-v4-flash
        gptel-default-mode 'org-mode
        gptel-confirm-tool-calls nil)
  :config
  (setq-default gptel-backend
                (gptel-make-deepseek "DeepSeek-thinking"
                  :stream t
                  :request-params '(:thinking (:type "enabled"))
                  :key #'gptel-api-key-from-auth-source))

  (add-hook 'gptel-post-stream-hook 'gptel-auto-scroll)
  (add-hook 'gptel-post-response-functions 'gptel-end-of-response)
  (with-eval-after-load 'embark
    (keymap-set embark-region-map "T" #'+gptel-rewrite-translate-to-chinese))
  )

(use-package gptel-agent
  :straight t
  :after gptel
  :config (gptel-agent-update))


(use-package gptel-magit
  :straight (gptel-magit :type git :host github :repo "roife/gptel-magit")
  :hook ((magit-mode . gptel-magit-install))
  :config
  (setq gptel-magit-body-length 72
        gptel-magit-commit-prompt (cdr (assoc "Conventional Commits" gptel-magit-commit-styles-alist))))

(use-package gptel-quick
  :straight (gptel-quick :type git :host github :repo "karthink/gptel-quick")
  :after (gptel embark)
  :config
  (setq gptel-quick-backend (gptel-make-deepseek "DeepSeek-quick"
                              :stream t
                              :request-params '(:thinking (:type "disabled"))
                              :key #'gptel-api-key-from-auth-source)
        gptel-quick-model 'deepseek-v4-flash
        gptel-quick-word-count 500
        gptel-quick-system-message (lambda (&rest _) "一句话解释："))
  (keymap-set embark-general-map "?" #'gptel-quick)
  )

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

;; Claude Code IDE — Claude Code CLI 的 Emacs 集成。
;; 通过 MCP 桥接 Emacs 与 Claude Code CLI:让 Claude 感知当前文件/选区/xref/
;; diagnostics,用 ediff 审阅改动,并可暴露自定义 Elisp 工具。前置依赖:已安装
;; `claude' CLI 并登录。终端后端沿用本配置的 ghostel(提供 `ghostel-exec')。
(use-package claude-code-ide
  :straight (:type git :host github :repo "manzaltu/claude-code-ide.el")
  ;; NOTE: 不要把 `ghostel' 放进 `:after' —— `use-package' 的 `:after' 会把
  ;; `:init' 也一并延迟到所有 :after feature 加载之后才执行。而 ghostel 在本
  ;; 配置里是 `:straight t' 惰性加载,平时不会自动 load。一旦 ghostel 未先被
  ;; 调起,这里的 `setq claude-code-ide-terminal-backend 'ghostel' 就不会跑,
  ;; backend 停留在上游 defcustom 默认值 `'vterm',随后 M-x claude-code-ide-menu
  ;; 会报 "vterm is not installed"。故仅以 `project' 作为 `:after' 门槛(运行期
  ;; 真正需要的只是 project);ghostel 由 `claude-code-ide--terminal-ensure-backend'
  ;; 在拉起会话时用 `(require 'ghostel nil t)' 现加载即可。
  :after (project)
  :bind (("C-c C-'" . claude-code-ide-menu))
  :init
  ;; 终端后端:用本配置已有的 ghostel(native module);可选 vterm / eat。
  (setq claude-code-ide-terminal-backend 'ghostel)

  ;; 窗口布局:右侧 side window,打开时不抢焦点(留在代码 buffer)。
  (setq claude-code-ide-use-side-window t
        claude-code-ide-window-side     'right
        claude-code-ide-window-width    100
        claude-code-ide-focus-on-open   nil)

  ;; diff:用 Emacs 原生 ediff 打开,审阅完再 apply。
  (setq claude-code-ide-use-ide-diff            t
        claude-code-ide-focus-claude-after-ediff nil
        claude-code-ide-show-claude-window-in-ediff t
        claude-code-ide-switch-tab-on-ediff      t)

  ;; 诊断:本配置用 flymake(init-prog),留 auto 自动识别 flymake/flycheck。
  (setq claude-code-ide-diagnostics-backend 'auto)

  ;; 缓冲命名:沿用 codex-ide 的 "<prefix>: <dir>" 风格(前缀用字面量,
  ;; claude-code-ide 没有 `-prefix' 变量,默认实现是 *claude-code[<dir>]*)。
  (setq claude-code-ide-buffer-name-function
        (lambda (dir)
          (if dir
              (format "claude-code: %s"
                      (file-name-nondirectory (directory-file-name dir)))
            "claude-code: Global")))

  ;; 允许 Claude 经 `executeCode' MCP 工具在 Emacs 内求值 Elisp。
  (setq claude-code-ide-enable-execute-code t)

  ;; CLI 额外参数:留空用 `claude' 默认账号;指定模型可如 "--model opus"。
  (setq claude-code-ide-cli-extra-flags "")
  :config
  ;; 启用内置 Emacs MCP 工具(xref-find-references / xref-find-apropos /
  ;; treesit-info / imenu-list-symbols / project-info)暴露给 Claude。
  (claude-code-ide-emacs-tools-setup))


;; ── agent-shell + Grok Build (ACP, 无 TUI) ─────────────────────────
;;
;; Grok Build 官方支持 `grok agent stdio`（Agent Client Protocol）。
;; agent-shell 用原生 Emacs buffer 驱动 agent，不走 Ghostel/终端 TUI。
;; 与 claude-code-ide（Ghostel+MCP）/ codex-ide（app-server）并存：
;;   C-c C-'  Claude Code IDE
;;   C-c C-;  Codex IDE（session buffer 内）
;;   C-c C-g  打开 Grok Build (agent-shell)
;;   在 Grok buffer 内：
;;     C-c C-c  中断当前 turn（不是关闭窗口）
;;     C-c C-q  关闭/bury 窗口；C-u C-c C-q 杀掉会话 buffer
;;
;; 上游尚无一等 `agent-shell-xai.el`（issue #708）；这里用与 Kiro 同模式的
;; 自定义 agent config，待官方模块合并后可删本地 wrapper。
;; Dependencies of agent-shell (MELPA). Declared explicitly so straight
;; installs them even before agent-shell is first required.
(use-package shell-maker
  :straight t)

(use-package acp
  :straight t)

(use-package agent-shell
  :straight t
  :commands (agent-shell
             agent-shell-xai-start-grok
             +agent-shell-start-grok)
  :bind (("C-c C-g" . +agent-shell-start-grok))
  :preface
  (defconst +agent-shell-grok-bin-dir
    (expand-file-name "~/.grok/bin")
    "Directory where the Grok Build installer places the `grok' binary.")

  (defun +agent-shell-ensure-grok-on-path ()
    "Ensure `~/.grok/bin' is on `exec-path' and process PATH."
    (when (file-directory-p +agent-shell-grok-bin-dir)
      (add-to-list 'exec-path +agent-shell-grok-bin-dir)
      (let ((path (getenv "PATH")))
        (unless (and path (string-match-p (regexp-quote +agent-shell-grok-bin-dir) path))
          (setenv "PATH" (concat +agent-shell-grok-bin-dir path-separator (or path "")))))))

  (defvar agent-shell-xai-grok-acp-command
    '("grok" "agent" "-m" "grok-4.5" "stdio")
    "Command and args for Grok Build ACP.
Examples:
  (\"grok\" \"agent\" \"stdio\")
  (\"grok\" \"agent\" \"-m\" \"grok-4.5\" \"stdio\")
  (\"grok\" \"agent\" \"--always-approve\" \"stdio\")")

  (defvar agent-shell-xai-grok-environment nil
    "Extra environment for the Grok ACP process.
Prefer `agent-shell-make-environment-variables' with `:inherit-env t'.")

  (defun agent-shell-xai-make-grok-config ()
    "Create a Grok Build agent configuration for `agent-shell'."
    (agent-shell-make-agent-config
     :identifier 'grok-build
     :mode-line-name "Grok"
     :buffer-name "Grok"
     :shell-prompt "Grok> "
     :shell-prompt-regexp "Grok> "
     :client-maker
     (lambda (buffer)
       (+agent-shell-ensure-grok-on-path)
       (unless (executable-find (car agent-shell-xai-grok-acp-command))
         (user-error
          "Cannot find `grok' on PATH. Install Grok Build CLI and ensure ~/.grok/bin is available (see https://docs.x.ai)"))
       (agent-shell--make-acp-client
        :command (car agent-shell-xai-grok-acp-command)
        :command-params (cdr agent-shell-xai-grok-acp-command)
        :environment-variables
        (or agent-shell-xai-grok-environment
            (agent-shell-make-environment-variables :inherit-env t))
        :context-buffer buffer))
     :install-instructions
     "Install Grok Build: curl -fsSL https://x.ai/cli/install.sh | bash
Ensure `grok' is on PATH (typically ~/.grok/bin). Run `grok login' once, or set XAI_API_KEY.
Docs: https://docs.x.ai/build/overview"))

  (defun agent-shell-xai-start-grok ()
    "Start an interactive Grok Build agent shell."
    (interactive)
    (require 'shell-maker)
    (require 'acp)
    (require 'agent-shell)
    (agent-shell--dwim :config (agent-shell-xai-make-grok-config)
                       :new-shell t))

  (defalias '+agent-shell-start-grok #'agent-shell-xai-start-grok)

  :init
  (+agent-shell-ensure-grok-on-path)
  ;; 普通右分窗，不要用 side-window。
  ;; side-window 下 C-x 1 / delete-other-windows 会报
  ;; "Cannot make side window the only window"，且容易删不掉主窗。
  (setq agent-shell-display-action
        '((display-buffer-reuse-window
           display-buffer-in-direction)
          (direction . right)
          (window-width . 0.42)))
  ;; C-c C-c 默认是 interrupt（打断当前 turn），不是关闭会话。
  (setq agent-shell-confirm-interrupt nil)

  :config
  (+agent-shell-ensure-grok-on-path)

  ;; Register Grok among known agents (upstream has no first-class module yet).
  (add-to-list 'agent-shell-agent-configs
               (agent-shell-xai-make-grok-config)
               t)

  ;; Always use Grok for `M-x agent-shell' (no agent picker).
  (setq agent-shell-preferred-agent-config 'grok-build)

  ;; Enable @file and /slash completion (ACP availableCommands).
  (setq agent-shell-file-completion-enabled t)

  (defun +agent-shell-quit (&optional kill)
    "Bury the agent-shell window, or with prefix KILL the session buffer.
`C-c C-c' only interrupts an in-flight turn; use this (or `C-c C-q')
to dismiss/close the Grok session."
    (interactive "P")
    (unless (derived-mode-p 'agent-shell-mode)
      (user-error "Not in an agent-shell buffer"))
    (if kill
        (let ((buf (current-buffer)))
          (when-let* ((win (get-buffer-window buf)))
            (quit-window t win))
          (when (buffer-live-p buf)
            (kill-buffer buf)))
      (quit-window nil (selected-window))))

  ;; 关闭会话：C-c C-q bury；C-u C-c C-q 杀掉 buffer/进程。
  (keymap-set agent-shell-mode-map "C-c C-q" #'+agent-shell-quit)
  ;; 避免 zoom 对 agent 窗反复 resize 触发奇怪的 window 错误。
  (with-eval-after-load 'zoom
    (cl-pushnew 'agent-shell-mode zoom-ignored-major-modes)))
