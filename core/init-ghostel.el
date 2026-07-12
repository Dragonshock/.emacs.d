;;; init-ghostel.el --- Ghostel terminal emulator (libghostty-vt) -*- lexical-binding: t -*-

;;; Commentary:
;; Terminal emulator powered by Ghostty's VT engine.  Supports Kitty
;; keyboard protocol, OSC 8 hyperlinks, synchronized output, 24-bit
;; color, and TRAMP remote terminals.  Replaces ansi-term as the
;; primary terminal emulator.

;;; Code:

;; ── Ghostel 主配置 ──────────────────────────────────────────
;;
;; Ghostel 是 Emacs 新一代终端模拟器，底层使用 Ghostty 的
;; libghostty-vt 引擎（Zig 编写）。原生动态模块提供 PTY I/O、
;; 终端状态管理和渲染；Elisp 层管理 keymap、buffer、命令和
;; 远程进程集成。
;;
;; 特性:
;;   • Kitty 键盘协议 & 图形协议（图片显示）
;;   • 24-bit 真彩色 & 丰富下划线样式
;;   • OSC 8 超链接 / OSC 7 目录跟踪 / OSC 133 提示符标记
;;   • 同步输出 (DEC 2026)
;;   • TRAMP 远程终端（自动 terminfo 安装、shell 集成注入）
;;   • 五种输入模式（semi-char / char / emacs / copy / line）
;;
;; 安装: 首次使用时自动下载预编译的原生模块（无需编译工具链）

(use-package ghostel
  :straight t
  ;; ── 全局快捷键 ──
  ;; C-x p m 留给 magit-status（init-tools）；终端用 t/T。
  :bind (("C-x m" . ghostel)                    ; 打开/切换 Ghostel 终端
         :map project-prefix-map
         ("t" . ghostel-project)                 ; 在当前项目目录打开
         ("T" . ghostel-project-list-buffers)    ; 列出项目相关的 ghostel buffer
         ;; 半字符模式下可用的 Emacs 快捷键
         :map ghostel-semi-char-mode-map
         ("C-s"  . consult-line)                 ; 搜索 scrollback
         ("C-k"  . +ghostel-send-C-k-and-kill)   ; 像 Emacs C-k：杀到行尾并进 kill-ring
         ("M-<backspace>" . ghostel-backward-kill-word)
         ;; 模拟 eshell 的 M-p/M-n 历史浏览（发送 C-p/C-n 给终端）
         ("M-p" . (lambda () (interactive) (ghostel-send-key "p" "ctrl")))
         ("M-n" . (lambda () (interactive) (ghostel-send-key "n" "ctrl"))))

  :init
  ;; ── 原生模块自动安装策略 ──
  ;; download = 自动下载预编译二进制（推荐，无需 zig）
  ;; ask      = 下载前询问
  ;; compile  = 从源码编译（需要 zig 0.15.2+）
  ;; nil      = 仅手动安装
  (setq ghostel-module-auto-install 'download
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

  ;; ── 渲染性能（针对 Claude Code 等持续高吞吐 TUI） ──
  ;; ghostel 把整个 scrollback 实体化进 Emacs buffer（带颜色/样式/链接
  ;; 文字属性），所以 scrollback 越大、redraw 越慢。Claude Code 依靠
  ;; TERM=xterm-ghostty 的 terminfo 发现 DEC 2026 同步输出协议，在重绘
  ;; 大 scrollback 时走 fast path（ghostel 在 DEC 2026 active 时会 skip
  ;; 非 force 的 redraw）。这里再提高 redraw 帧率，让同步输出间隙的
  ;; 重绘更顺滑。
  ;; 基底帧率 30fps → ~60fps；adaptive-fps 仍开（空闲时停 timer）。
  (setq ghostel-timer-delay 0.016          ; ~60fps 基底（默认 0.033 ≈30fps）
        ghostel-adaptive-fps t             ; 空闲停 timer，交互时短延迟
        ghostel-immediate-redraw-interval 0.05)  ; 键入后 50ms 内的输出立即重绘
  ;; scrollback 保持默认 5MB（~5000 行）。Claude 会话内的历史由其 TUI
  ;; alternate screen 自管；ghostel scrollback 主要存 prompt 间输出，5MB
  ;; 足够且 redraw 不致拖慢。如需更多历史可调 ghostel-max-scrollback，
  ;; 但值越大持续输出越慢。

  ;; ── Shell 集成（自动目录跟踪 & 提示符导航） ──
  ;; 默认 t：bash/zsh/fish 自动注入集成脚本，无需修改 shell 配置
  (setq ghostel-shell-integration t)

  ;; ── 从 Shell 调用 Emacs 函数 ──
  ;; 将可信函数加入白名单后，可在 shell 中用 `ghostel_cmd' 调用
  (add-to-list 'ghostel-eval-cmds '("magit-status-setup-buffer" magit-status-setup-buffer))

  ;; ── 终端类型 ──
  ;; 默认 xterm-ghostty（完整能力集）。如在远程主机上遇到
  ;; "Error opening terminal" 可改为 "xterm-256color" 降级
  ;; (setq ghostel-term "xterm-256color")

  ;; ── 复制模式行为 ──
  ;; 鼠标拖拽选择时自动进入的模式（copy / emacs / nil 不切换）
  (setq ghostel-mouse-drag-input-mode 'copy)
  ;; 键盘激活 mark 时自动进入的模式
  (setq ghostel-mark-activation-input-mode 'copy)

  ;; ── TRAMP 远程终端配置 ────────────────────────────
  ;; 当 default-directory 是 TRAMP 路径时（如 /ssh:host:/path/），
  ;; M-x ghostel 会通过 TRAMP 在远程主机上启动 shell。

  ;; 远程 shell 类型：按 TRAMP 方法指定使用的 shell
  (setq ghostel-tramp-shells
        '(("ssh"    login-shell "/bin/bash")  ; SSH: 自动检测登录 shell，失败用 bash
          ("scp"    login-shell "/bin/bash")  ; SCP: 同上
          ("docker" "/bin/sh")                ; Docker: 用 sh
          ("podman" "/bin/sh")))              ; Podman: 用 sh

  ;; 远程 shell 集成：自动将集成脚本传输到远程主机（临时文件）
  ;; t     = 对所有远程会话启用
  ;; nil   = 禁用（手动配置远程 shell rc）
  ;; 列表  = 仅对列表中的 TRAMP 方法启用
  (setq ghostel-tramp-shell-integration
        '("ssh" "scp"))  ; 仅对 SSH/SCP 透明启用

  ;; 远程 terminfo 安装：自动将 xterm-ghostty terminfo 推送到远程
  ;; auto = 当 ghostel-tramp-shell-integration 非 nil 时自动启用
  ;; t    = 始终启用
  ;; nil  = 禁用（手动在远程安装 terminfo）
  (setq ghostel-ssh-install-terminfo 'auto)

  ;; 远程默认 TRAMP 方法（用于 OSC 7 目录跟踪时构造路径）
  ;; 留空使用 tramp-default-method，也可覆盖为 "scp" 等
  ;; (setq ghostel-tramp-default-method "ssh")

  ;; ── 密码提示 ──
  ;; sudo/ssh/passwd 等需要密码时，Ghostel 弹出 minibuffer 读取
  ;; 而非将密码回显到终端。此行为自动工作，无需额外配置。
  )

;; ── Ghostel Compile：编译输出使用 Ghostel 终端 ─────────────
;;
;; 启用后，M-x compile / recompile / project-compile 的输出
;; 会在 Ghostel buffer 中显示（而非默认的 *compilation* buffer）。
;; 好处：终端颜色完整渲染、交互式 TUI 编译工具支持。
(use-package ghostel-compile
  :straight nil
  :hook (after-init . ghostel-compile-global-mode)
  :config
  ;; 如果希望在编译 buffer 中使用 Emacs 快捷键浏览输出：
  ;; 编译 buffer 默认是 ghostel-compile-view-mode（只读），
  ;; 可以使用 isearch / consult-line / occur 搜索编译日志。
  )

;; ── Ghostel Comint：将 comint 模式集成到 Ghostel ────────────
;;
;; 启用后，run-python / run-scheme / sql-* 等 comint-based REPL
;; 会自动使用 Ghostel 作为终端后端。这样可以享受完整的
;; ANSI 转义序列支持和更流畅的输出渲染。
(use-package ghostel-comint
  :straight nil
  :hook (after-init . ghostel-comint-global-mode))

;; ── Ghostel Eshell：Eshell 中的可视化命令转 Ghostel ─────────
;;
;; 启用后，在 Eshell 中运行视觉命令（如 htop、less、vim 等）
;; 时会自动切换到 Ghostel buffer 中执行，命令结束后返回 Eshell。
;; 这解决了 Eshell 对全屏 TUI 程序支持不佳的问题。
(use-package ghostel-eshell
  :straight nil
  :hook (eshell-load . ghostel-eshell-visual-command-mode))

;; ── Ghostel 输入模式速查 ──────────────────────────────────
;;
;; 模式切换快捷键（除 char mode 外所有模式通用）:
;;   C-c C-j  → semi-char（默认模式，大部分键发送到终端）
;;   C-c M-d  → char（所有键发送到终端，用于 htop/vim 等）
;;   C-c C-e  → emacs（只读，终端保持运行，可搜索/复制）
;;   C-c C-t  → 切换 copy 模式（终端冻结，精确选择文本）
;;   C-c C-l  → line（本地编辑输入，RET 发送整行）
;;   M-RET    → char mode 专属：返回 semi-char
;;
;; semi-char 模式下保留给 Emacs 的键（ghostel-keymap-exceptions）:
;;   C-c C-x C-u C-h M-x M-: C-\
;;
;; semi-char 模式实用快捷键:
;;   C-c C-c  → 发送 SIGINT
;;   C-c C-z  → 发送 SIGTSTP
;;   C-c C-d  → 发送 EOF
;;   C-c M-w  → 复制全部 scrollback 到 kill-ring
;;   C-y      → 粘贴（bracketed paste）
;;   C-c C-n  → 跳转到下一个超链接
;;   C-c C-p  → 跳转到上一个超链接
;;   C-c M-n  → 进入 Emacs 模式并跳到下一个提示符
;;   C-c M-p  → 进入 Emacs 模式并跳到上一个提示符

(provide 'init-ghostel)

;;; init-ghostel.el ends here
