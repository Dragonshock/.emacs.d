;;; -*- lexical-binding: t -*-
;;; init-grok.el --- Local Grok Build IDE (ACP native client) -*- lexical-binding: t; -*-

;; grok-ide：基于 `grok agent stdio` 的原生 Emacs 客户端（非 TUI）。
;; 源码在本机仓库 `~/Desktop/Grok-Build-ide/grok-ide`（开发中，不走 straight）。
;;
;; 与现有 AI 入口并存（见 init-ai.el）：
;;   C-c C-'  Claude Code IDE
;;   C-c C-;  Codex IDE（session buffer 内）
;;   C-c C-g  Grok via agent-shell（通用 ACP shell）
;;   C-c C-j  Grok IDE（本文件：codex-ide 风格的原生客户端）
;;   C-c M-j  Grok IDE resume（磁盘会话）
;;
;; 前置：
;;   - Emacs 28.1+（本机 31 OK）
;;   - `grok` CLI（通常 ~/.grok/bin 或 ~/.local/bin）
;;   - `grok login` 已完成
;;   - MCP bridge 需要 emacsclient → 本文件会确保 `server-start`

(defconst +grok-ide-package-dir
  (expand-file-name "~/Desktop/Grok-Build-ide/grok-ide")
  "Local checkout of the grok-ide package.")

(defconst +grok-ide-bin-dir
  (expand-file-name "~/.grok/bin")
  "Directory where the Grok Build installer places the `grok' binary.")

(defun +grok-ide-ensure-path ()
  "Ensure Grok CLI directories are on `exec-path' and process PATH."
  (dolist (dir (list +grok-ide-bin-dir
                     (expand-file-name "~/.local/bin")))
    (when (file-directory-p dir)
      (add-to-list 'exec-path dir)
      (let ((path (getenv "PATH")))
        (unless (and path (string-match-p (regexp-quote dir) path))
          (setenv "PATH" (concat dir path-separator (or path ""))))))))

(defun +grok-ide-ensure-server ()
  "Start Emacs server when needed for the MCP bridge."
  (require 'server)
  (unless (and (fboundp 'server-running-p) (server-running-p))
    (server-start)))

;; Local package: do not use :straight.  Add load-path explicitly so
;; development checkouts work without a recipe.
(add-to-list 'load-path +grok-ide-package-dir)

(use-package grok-ide
  :commands (grok-ide
             grok-ide-new-session
             grok-ide-resume
             grok-ide-list-sessions
             grok-ide-stop
             grok-ide-show-log
             grok-ide-set-model
             grok-ide-toggle-always-approve)
  :preface
  (defun +grok-ide-submit-or-newline ()
    "Submit one-line Grok prompts with RET; otherwise insert a newline.

Mirror of `+codex-ide-submit-or-newline' in init-ai.el."
    (interactive)
    (let* ((session (and (boundp 'grok-ide--session) grok-ide--session))
           (start (and session (grok-ide-session-input-marker session)))
           (text (and session (grok-ide-transcript-read-input session))))
      (if (and (markerp start)
               (stringp text)
               (not (string-empty-p text))
               (not (string-match-p "\n" text)))
          (grok-ide-submit)
        (newline))))
  :bind (("C-c C-j" . grok-ide)
         ("C-c M-j" . grok-ide-resume)
         :map grok-ide-session-mode-map
         ("RET" . +grok-ide-submit-or-newline)
         ("<return>" . +grok-ide-submit-or-newline)
         ("S-<return>" . newline)
         ("C-c C-;" . grok-ide-set-model)
         ("C-c C-a" . grok-ide-toggle-always-approve))
  :init
  (+grok-ide-ensure-path)

  ;; ── 与 codex-ide（init-ai.el）对齐的习惯 ─────────────────────────
  ;; codex-ide 默认关闭 MCP bridge；grok-ide 的 Emacs MCP 工具是可选增强，
  ;; 这里默认开启（需要 server-start / emacsclient）。
  (setq grok-ide-cli-path (or (and (progn (+grok-ide-ensure-path) t)
                                   (executable-find "grok"))
                              "grok")
        grok-ide-model "grok-4.5"
        grok-ide-always-approve nil
        ;; 对齐 codex-ide-emacs-context-policy = nil：默认不注入文本 context，
        ;; 依赖 Emacs MCP bridge 拉 live 上下文，避免 transcript 被 context 污染。
        grok-ide-include-editor-context nil
        grok-ide-show-thinking t
        grok-ide-show-end-turn nil
        grok-ide-fs-write-enabled nil
        grok-ide-render-markdown t
        grok-ide-logging-enabled t
        grok-ide-log-max-lines 5000
        grok-ide-select-window-on-open t
        grok-ide-tool-sections-collapsed t
        grok-ide-load-timeout 180
        ;; MCP：t 总是开；prompt 启动时询问；nil 关闭
        grok-ide-want-mcp-bridge t
        grok-ide-enable-emacs-tool-bridge t
        grok-ide-suppress-server-start-prompts t
        grok-ide-emacs-tool-bridge-name "emacs"
        grok-ide-buffer-name-prefix "grok-ide")

  :config
  (+grok-ide-ensure-path)

  (unless (file-directory-p +grok-ide-package-dir)
    (warn "grok-ide package dir missing: %s" +grok-ide-package-dir))

  (unless (executable-find grok-ide-cli-path)
    (warn "Cannot find `grok' on PATH. Install Grok Build CLI (see https://docs.x.ai)"))

  ;; MCP bridge 需要 emacsclient 打回本 Emacs。
  (when (and (fboundp 'grok-ide-mcp-bridge-enabled-p)
             (grok-ide-mcp-bridge-enabled-p))
    (+grok-ide-ensure-server)
    (when (fboundp 'grok-ide-mcp-bridge-ensure-server)
      (grok-ide-mcp-bridge-ensure-server)))

  ;; 右侧分窗展示（对齐 agent-shell 习惯；名称形如 *grok-ide[dir]*）。
  (setq display-buffer-alist
        (cons
         '("\\`\\*grok-ide"
           (display-buffer-reuse-window display-buffer-in-direction)
           (direction . right)
           (window-width . 0.42)
           (reusable-frames . visible))
         display-buffer-alist))

  ;; 避免 zoom 对会话窗反复 resize。
  (with-eval-after-load 'zoom
    (cl-pushnew 'grok-ide-session-mode zoom-ignored-major-modes)))

(provide 'init-grok)

;;; init-grok.el ends here
