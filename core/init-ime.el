;;; -*- lexical-binding: t; -*-

(defun +liberime-prepend-env-path (name path)
  (when (file-directory-p path)
    (let ((value (getenv name)))
      (unless (member path (and value (split-string value path-separator t)))
        (setenv name
                (if (and value (not (string= value "")))
                    (concat path path-separator value)
                  path))))))

(when (eq system-type 'darwin)
  (+liberime-prepend-env-path "CPATH" "/opt/homebrew/include")
  (+liberime-prepend-env-path "LIBRARY_PATH" "/opt/homebrew/lib"))

(use-package liberime
  :straight (liberime :type git :host github :repo "emacs-rime/liberime")
  :demand t
  :init
  (setq liberime-auto-build t
        ;; 共享数据目录：复用 Squirrel 的 ~/Library/Rime，里面有全套
        ;; schema / 词库 / lua / symbols / custom_phrase，零成本沿用现有配置。
        ;; librime 会忽略其中的前端文件（squirrel.yaml / weasel.yaml）。
        liberime-shared-data-dir "~/Library/Rime/"
        ;; 用户数据目录与 Squirrel 分开：userdb（用户词库、词频）和
        ;; installation_id 独立，避免两个前端部署时互相覆盖部署状态与词库。
        ;; schema/词库由上面的 shared-data-dir 提供，这里只放部署产物与
        ;; installation.yaml / default.custom.yaml。
        liberime-user-data-dir "~/.emacs.d/rime/")
  :config
  ;; librime 的 lua 脚本搜索路径是 <user-data-dir>/lua/，而 lua 源文件在
  ;; shared-data-dir（~/Library/Rime/lua）。liberime-start 的 deploy 会清掉
  ;; user-data-dir/lua 的软链接（但不会删真文件目录），所以这里用真文件复制，
  ;; 并在每次启动前同步：Squirrel 那边 lua 更新后，Emacs 这边也能跟上。
  (defun +liberime-sync-lua-scripts ()
    "把 shared-data-dir/lua 的脚本同步（复制）到 user-data-dir/lua。"
    (let ((src (expand-file-name "lua/" liberime-shared-data-dir))
          (dst (expand-file-name "lua/" liberime-user-data-dir)))
      (when (file-directory-p src)
        (make-directory dst t)
        (dolist (f (directory-files src t directory-files-no-dot-files-regexp))
          (let ((target (expand-file-name (file-name-nondirectory f) dst)))
          (cond
           ((file-directory-p f)
            ;; 递归复制子目录（如 cold_word_drop/）
            (unless (file-symlink-p target)
              (copy-directory f target t t t)))
           ((file-regular-p f)
            (copy-file f target t t))))))))
  (add-hook 'liberime-after-start-hook #'+liberime-sync-lua-scripts))

(use-package rimel
  :straight (rimel :type git :host github :repo "emacs-rime/rimel")
  :after liberime
  :demand t
  :custom-face
  (rimel-candidate-label-face ((t (:inherit font-lock-comment-face :height 0.85))))
  (rimel-page-indicator-face ((t (:inherit font-lock-comment-face :height 0.85))))
  (rimel-highlight-face ((t (:inherit hl-line))))
  :init
  (setq default-input-method "rimel")
  :bind ("C-SPC" . toggle-input-method)
  :config
  (setq rimel-show-candidate 'posframe
        rimel-inline-preedit t
        rimel-candidate-show-preedit nil
        rimel-posframe-style 'horizontal
        rimel-posframe-properties nil
        rimel-candidate-label-format "%d "
        rimel-page-indicator-format "%d%s"
        rimel-disable-predicates '(rimel-predicate-prog-in-code-p
                                   rimel-predicate-current-uppercase-letter-p
                                   rimel-predicate-org-in-src-block-p
                                   rimel-predicate-org-latex-mode-p
                                   rimel-predicate-tex-math-or-command-p))
  ;; 兜底：独立 rime 目录首次部署后选中雾凇拼音方案。
  ;; 注意：未启用 rimel-predicate-after-alphabet-char-p —— 该断言会在光标前
  ;; 是英文字母时禁用中文，对不用 evil/meow 的纯 Emacs 用户会导致"在任何英文
  ;; 文本后都无法开始中文输入"。代码区仍由 prog-in-code-p 守卫，大写字母仍由
  ;; current-uppercase-letter-p 守卫，中英切换靠 C-SPC + sis 自动。
  (with-eval-after-load 'liberime
    (liberime-try-select-schema "rime_ice")))

;; [sis] automatically switch input source
(use-package sis
  :straight t
  :hook (;; Enable the inline-english-mode for all buffers.
         ;; When add space after chinese char, automatically switch to english mode
         (after-init . sis-global-inline-mode)
         ;; Enable the context-mode for all buffers
         (after-init . sis-global-context-mode)
         ;; Colored cursor
         (after-init . sis-global-cursor-color-mode))
  :config
  ;; Use rimel as default
  (sis-ism-lazyman-config nil "rimel" 'native)

  ;; HACK: Set cursor color automatically
  (add-hook! (enable-theme-functions server-after-make-frame-hook) :unless-daemonp-call-immediately
    (defun +sis-set-cursor-color (&rest _)
      (setq sis-other-cursor-color (face-foreground 'error nil t)
            sis-default-cursor-color (face-background 'cursor nil t))))

  ;; Recover the terminal cursor color when leaving Emacs (TUI only).
  (add-hook! kill-emacs-hook
    (defun +sis-reset-terminal-cursor-color ()
      (unless (display-graphic-p)
        (send-string-to-terminal "\e]112\a"))))

  (defconst +sis-chinese-puncs "，。？！；：（【「“")

  (defconst +sis-chinese-punc-chars (string-to-list +sis-chinese-puncs))

  (defun +sis-remove-head-space-after-cc-punc (_)
    (when (or (memq (char-before) +sis-chinese-punc-chars)
              (bolp))
      (delete-char 1)))
  (setq sis-inline-tighten-head-rule #'+sis-remove-head-space-after-cc-punc)

  (defun +sis-remove-tail-space-before-cc-punc (_)
    (when (eq (char-before) ? )
      (backward-delete-char 1)
      (when (and (eq (char-before) ? )
                 (memq (char-after) +sis-chinese-punc-chars))
        (backward-delete-char 1))))
  (setq sis-inline-tighten-tail-rule #'+sis-remove-tail-space-before-cc-punc)

  ;; Context mode —— 不依赖 meow/evil：sis 自带的 detector 依据光标前后
  ;; 字符判断中/英，上下文 hook 用 post-command-hook 即可。
  ;; Ignore some mode with context mode
  (defadvice! +sis-context-guess-ignore-modes (fn &rest args)
    :around #'sis--context-guess
    (if (derived-mode-p 'pdf-view-mode)
        'english
      (apply fn args)))

  (defun +sis-context-switching-other (back-detect fore-detect)
    "在 Org/Markdown/纯文本，或 telega 聊天输入区，按上下文切到中文。"
    (when (or (and (derived-mode-p 'org-mode 'markdown-mode 'text-mode)
                   (sis--context-other-p back-detect fore-detect))
              (and (derived-mode-p 'telega-chat-mode)
                   (or (and (boundp 'telega-chatbuf--input-marker)
                            (= (point) telega-chatbuf--input-marker)
                            (eolp))
                       (sis--context-other-p back-detect fore-detect))))
      'other))

  (add-to-list 'sis-context-detectors #'+sis-context-switching-other)

  ;; Inline-mode
  (defvar-local +sis-inline-english-last-space-pos nil
    "The last space position in inline mode.")

  (add-hook! sis-inline-english-deactivated-hook
    (defun +sis-line-set-last-space-pos ()
      (when (eq (char-before) ?\s)
        (setq +sis-inline-english-last-space-pos (point)))))

  (add-hook! sis-inline-mode-hook
    (defun +sis-inline-add-post-self-insert-hook ()
      (add-hook! post-self-insert-hook :local
        (defun +sis-inline-remove-redundant-space ()
          (when (and (eq +sis-inline-english-last-space-pos (1- (point)))
                     (looking-back (concat " [" +sis-chinese-puncs "]")))
            (save-excursion
              (backward-char 2)
              (delete-char 1)
              (setq-local +sis-inline-english-last-space-pos nil))))))))
