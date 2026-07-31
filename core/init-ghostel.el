;;; init-ghostel.el --- Ghostel terminal emulator (libghostty-vt) -*- lexical-binding: t -*-

;;; Commentary:
;; Terminal emulator powered by Ghostty's VT engine.  Supports Kitty
;; keyboard protocol, OSC 8 hyperlinks, synchronized output, 24-bit
;; color, and TRAMP remote terminals.  Replaces ansi-term as the
;; primary terminal emulator.
;;
;; Performance notes (see ghostel README §Performance):
;; - Full scrollback is materialized into the Emacs buffer with text
;;   properties; larger scrollback and higher redraw rates cost main-thread time.
;; - Keep `ghostel-timer-delay' at the default (~30fps).  Raising to 60fps
;;   increases redraw work and often freezes Emacs under high-throughput TUIs.
;; - Prefer native PTY (default) for local shells; TRAMP always uses Emacs
;;   process filters and can block the UI on large remote output.
;; - Do not enable ghostel-comint-global-mode if you use agent-shell
;;   (shell-maker is comint-derived; double-filtering hurts streaming).

;;; Code:

;; ── Ghostel 主配置 ──────────────────────────────────────────
;;
;; Ghostel 底层使用 Ghostty 的 libghostty-vt（Zig）。原生模块提供
;; PTY I/O / 终端状态 / 渲染；Elisp 管理 keymap、buffer、命令与远程集成。
;;
;; 安装: 首次使用时自动下载预编译原生模块（无需 zig）。
;; 模块目录: set in init-basic via no-littering (`var/ghostel/`).
;; 若 Elisp 要求的最低版本高于 sidecar（ghostel-module.version），
;; 会按 `ghostel-module-auto-install' 策略重装（当前 Elisp 要求 ≥0.45.0）。

(use-package ghostel
  :straight t
  ;; ── 全局快捷键 ──
  ;; C-x p m 留给 magit-status（init-tools）；终端用 project map 的 m/M。
  :bind (("C-x m" . ghostel)
         :map ghostel-semi-char-mode-map
         ;; Keep C-g for Emacs quit (roife); otherwise it may go to the shell.
         ("C-g"  . keyboard-quit)
         ("C-k"  . +ghostel-send-C-k-and-kill)
         ;; Eshell-style history: M-p/n → C-p/n for the shell.
         ("M-p" . (lambda () (interactive) (ghostel-send-key "p" "ctrl")))
         ("M-n" . (lambda () (interactive) (ghostel-send-key "n" "ctrl")))
         :map project-prefix-map
         ("m" . ghostel-project)              ; 在当前项目目录打开
         ("M" . ghostel-project-list-buffers)) ; 列出项目相关的 ghostel buffer

  :init
  ;; ── 原生模块 ──
  ;; download = 自动下载预编译二进制（推荐）
  ;; ask / compile / nil 见 ghostel-module-auto-install docstring
  ;; `ghostel-module-directory' is themed by no-littering in init-basic.
  (setq ghostel-module-auto-install 'download
        ;; OSC 52: programs can set the kill-ring/clipboard.  Useful over
        ;; SSH; disabled by upstream default for security.
        ghostel-enable-osc52 t)

  :preface
  (defun +ghostel-send-C-k-and-kill ()
    "Send C-k to the terminal and copy the rest of the line to the kill-ring."
    (interactive)
    (kill-ring-save (point) (line-end-position))
    (ghostel-send-key "k" "ctrl"))

  :config
  ;; ── 项目切换命令注册（project.el 加载后才可用） ──
  (with-eval-after-load 'project
    (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)
    (add-to-list 'project-switch-commands '(ghostel-project-list-buffers "Ghostel buffers") t))

  ;; Name project terminals as popper-friendly buffers (used by +eshell-toggle C-u).
  (defadvice! +ghostel-project-popup-buffer-name (_orig root)
    :around #'ghostel--project-buffer-name
    "Name `ghostel-project' buffers as Popper popup buffers for ROOT."
    (let* ((project-name (file-name-nondirectory
                          (directory-file-name root)))
           (remote (file-remote-p root))
           (remote-suffix (when remote
                            (format "@%s" (string-trim remote "/" ":")))))
      (format "Ghostel-popup: %s%s" project-name (or remote-suffix ""))))

  ;; ── 渲染：保持上游默认 ──
  ;; ghostel-timer-delay 默认 0.033（~30fps）。不要降到 0.016：
  ;; scrollback 整段 materialize 进 buffer，更高帧率 = 更多主线程 redraw。
  ;; adaptive-fps / immediate-redraw-interval 默认已合理，无需 setq。
  ;; scrollback 默认 5MB；越大，持续高吞吐输出越慢。
  ;; 高密度 URL/路径输出可临时:
  ;;   (setq ghostel-enable-url-detection nil
  ;;         ghostel-enable-file-detection nil)

  ;; ── Shell 集成（默认 t：bash/zsh/fish 自动注入） ──
  (setq ghostel-shell-integration t)

  ;; ── 从 Shell 调用 Emacs 函数 ──
  (add-to-list 'ghostel-eval-cmds '("magit-status-setup-buffer" magit-status-setup-buffer))

  ;; ── 终端类型 ──
  ;; 默认 xterm-ghostty。远程 "Error opening terminal" 时可降级:
  ;; (setq ghostel-term "xterm-256color")

  ;; ── 复制模式行为 ──
  ;; copy mode freezes terminal output (by design) while selecting.
  (setq ghostel-mouse-drag-input-mode 'copy
        ghostel-mark-activation-input-mode 'copy)

  ;; ── TRAMP 远程终端 ────────────────────────────
  (setq ghostel-tramp-shells
        '(("ssh"    login-shell "/bin/bash")
          ("scp"    login-shell "/bin/bash")
          ("docker" "/bin/sh")
          ("podman" "/bin/sh"))
        ;; Shell types (or t), not TRAMP method names — methods live above.
        ghostel-tramp-shell-integration t
        ghostel-ssh-install-terminfo 'auto)
  )

;; ── Ghostel Compile（默认关闭全局劫持） ─────────────────────
;;
;; 全局开启后，所有 compile / recompile / project-compile 走 ghostel，
;; 大构建日志会放大 redraw 压力。按需手动:
;;   M-x ghostel-compile
;;   M-x ghostel-compile-global-mode
;;
;; (use-package ghostel-compile
;;   :straight nil
;;   :hook (after-init . ghostel-compile-global-mode))

;; ── Ghostel Comint（默认关闭全局劫持） ──────────────────────
;;
;; 全局开启会挂到每一个 comint 派生 buffer（含未来 agent-shell /
;; shell-maker），与 agent 流式输出叠滤容易卡顿或显示错乱。
;; 若只要 shell/python REPL 的真彩色，可按 mode hook 局部开启:
;;   (add-hook 'shell-mode-hook #'ghostel-comint-mode)
;;
;; (use-package ghostel-comint
;;   :straight nil
;;   :hook (after-init . ghostel-comint-global-mode))

;; ── Ghostel Eshell：视觉命令转到 Ghostel ────────────────────
(use-package ghostel-eshell
  :straight nil
  :hook (eshell-load . ghostel-eshell-visual-command-mode))

;; ── Ghostel 输入模式速查 ──────────────────────────────────
;;
;;   C-c C-j  → semi-char（默认）
;;   C-c M-d  → char（全键进终端）
;;   C-c C-e  → emacs（只读，输出仍更新）
;;   C-c C-t  → copy（冻结输出，精确选择）
;;   C-c C-l  → line
;;   M-RET    → char → 回到 semi-char
;;
;; semi-char 保留给 Emacs: C-c C-x C-u C-h M-x M-: C-\ （及本配置的 C-g）
;;   C-c C-c  SIGINT · C-c C-z SIGTSTP · C-c C-d EOF
;;   C-c M-w  复制全部 scrollback · C-y bracketed paste
;;   C-c C-n/p  超链接 · C-c M-n/p  提示符导航（进 emacs mode）

(provide 'init-ghostel)

;;; init-ghostel.el ends here
