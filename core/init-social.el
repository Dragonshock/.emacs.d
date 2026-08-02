;; -*- lexical-binding: t; -*-
(use-package telega
  ;; Include Makefile + server/ so `telega-server-build' can recompile
  ;; against `telega-server-libs-prefix' (straight's default files omit them).
  :straight (:host github :repo "zevlg/telega.el"
                   :files (:defaults "contrib/*.el" "etc" "Makefile" "server"))
  :preface
  (defun +telega-install-tdlib ()
    "Fetch and install telega's expected TDLib commit under ~/.local."
    (interactive)
    (unless (eq system-type 'darwin)
      (user-error "+telega-install-tdlib currently only supports macOS"))
    (require 'telega)
    (require 'compile)
    (let ((script (expand-file-name "scripts/install-telega-tdlib" user-emacs-directory))
          (version (telega-dockrefile-tdlib-version))
          (prefix (expand-file-name "~/.local")))
      (unless (file-executable-p script)
        (user-error "TDLib install script is not executable: %s" script))
      (compilation-start
       (mapconcat #'shell-quote-argument (list script version prefix) " ")
       'compilation-mode
       (lambda (_) "*telega-install-tdlib*"))))

  (defun +telega--server-src-directory ()
    "Directory that contains telega's top-level Makefile and server/ sources.
Prefer the straight git repo; fall back to `telega--lib-directory'."
    (or (and (boundp 'straight-base-dir)
             (let ((dir (expand-file-name "straight/repos/telega.el"
                                          straight-base-dir)))
               (and (file-exists-p (expand-file-name "Makefile" dir))
                    (file-directory-p (expand-file-name "server" dir))
                    dir)))
        (and (boundp 'telega--lib-directory)
             telega--lib-directory
             (file-exists-p (expand-file-name "Makefile" telega--lib-directory))
             telega--lib-directory)))

  (defun +telega-toggle-archive ()
    "Toggle telega root buffer between the main and archive filters."
    (interactive)
    (let* ((archive-p (equal (telega-filter-active) '(archive)))
           (filter (if archive-p (list telega-filter-default) '(archive))))
      (telega-filters-push filter)
      (message "telega filter: %s" (if archive-p telega-filter-default 'archive))))

  (defvar +telega-unread-summary-prompt
    "你收到的是一批 Telegram 未读消息，每条格式为「发送者: 内容」。\
请将其改写为一份中文结构化摘要，使用 org-mode 标题格式，结构如下：

* 总览
用一两句话概括这批消息整体在讲什么、大致氛围。

* 重点关注
挑出 3-5 条最重要或信息量最大的内容（重大新闻、结论、决定、\
可执行信息），每条一行并注明发送者；链接、数字、版本号、时间等\
关键细节必须原样保留。

* 分类要点
将其余内容按主题归类（类别名按实际内容起，如：技术讨论、新闻资讯、\
产品发布、资源分享、闲聊），每类下用列表给出要点。同一话题多人讨论\
时合并成一条并写明分歧；重复转发的相同内容只保留一次；纯表情、\
打招呼和无信息量的寒暄直接忽略。

规则：忠于原文，不虚构、不加评论；输出只包含以上结构。"
    "用于 `+telega-summarize-unread' 的总结提示词。")

  (defvar +telega-summary-engine 'grok
    "未读消息总结引擎。
`grok'  —— Grok Build CLI 单轮 headless 调用（订阅登录，无需 API key）；
`gptel' —— gptel 的 DeepSeek 后端（rewrite 覆盖式）。")

  (defvar +telega-grok-bin (expand-file-name "~/.grok/bin/grok")
    "Grok Build CLI 路径（agent-shell 模块装好的那个）。")

  (defun +telega--grok-summarize (buf)
    "用 Grok Build CLI 异步总结 BUF 里的消息文本。
总结插入 buffer 顶部；原始消息保留在文末标题下并折叠。"
    (let* ((grok (if (file-executable-p +telega-grok-bin)
                     +telega-grok-bin
                   (or (executable-find "grok")
                       (user-error
                        "未找到 Grok Build CLI；(setq +telega-summary-engine 'gptel) 可回退"))))
           (text (with-current-buffer buf (buffer-string)))
           (prompt-file (make-temp-file "telega-unread-" nil ".txt" text)))
      (with-current-buffer buf
        (goto-char (point-min))
        (insert "* 原始消息\n")
        (goto-char (point-min))
        (setq header-line-format " ⏳ Grok 总结中…"))
      (make-process
       :name "telega-grok-summary"
       :buffer (generate-new-buffer " *telega-grok-out*")
       ;; --cwd 指向临时目录，避免 CLI 扫描项目上下文（AGENTS.md 等）
       :command (list grok
                      "--prompt-file" prompt-file
                      "--system-prompt-override" +telega-unread-summary-prompt
                      "--disable-web-search" "--no-subagents" "--no-plan"
                      "--no-memory" "--permission-mode" "dontAsk"
                      "--output-format" "plain" "--verbatim"
                      "--cwd" (temporary-file-directory))
       :sentinel
       (lambda (proc event)
         (let ((out-buf (process-buffer proc)))
           (unwind-protect
               (if (and (eq (process-status proc) 'exit)
                        (zerop (process-exit-status proc)))
                   (let ((summary (with-current-buffer out-buf
                                    (string-trim (buffer-string)))))
                     (if (not (buffer-live-p buf))
                         (message "telega: Grok 总结完成，但目标 buffer 已关闭")
                       (with-current-buffer buf
                         (setq header-line-format nil)
                         (goto-char (point-min))
                         (insert summary "\n\n")
                         (goto-char (point-min))
                         (when (re-search-forward "^\\* 原始消息$" nil t)
                           (beginning-of-line)
                           (ignore-errors (org-fold-hide-subtree)))
                         (goto-char (point-min)))
                       (message "telega: Grok 总结完成")))
                 (when (buffer-live-p buf)
                   (with-current-buffer buf
                     (setq header-line-format " ❌ Grok 总结失败")))
                 (message "telega: Grok 总结失败（%s）：%s"
                          (string-trim event)
                          (with-current-buffer out-buf
                            (truncate-string-to-width
                             (string-trim (buffer-string)) 200))))
             (ignore-errors (delete-file prompt-file))
             (kill-buffer out-buf)))))))

  (defun +telega-summarize-unread ()
    "汇集当前聊天的全部未读消息，用专用提示词做归类式总结。
直接从 TDLib 分页拉取（不依赖 chatbuf 已渲染的历史），未读几百条
也能一次取全。文本汇入新 buffer 后自动触发总结。"
    (interactive)
    (unless (derived-mode-p 'telega-chat-mode)
      (user-error "仅在 telega chat buffer 中可用"))
    (let* ((chat telega-chatbuf--chat)
           (unread (plist-get chat :unread_count))
           (last-read (plist-get chat :last_read_inbox_message_id))
           (title (telega-chat-title chat))
           (msgs nil)
           (from-id 0)
           (keep t))
      (when (zerop unread)
        (user-error "该聊天没有未读消息"))
      (message "telega: 正在拉取 %d 条未读消息..." unread)
      ;; getChatHistory 返回从新到旧，push 累积后 msgs 恰为时间顺序；
      ;; 翻页直到越过 last_read_inbox_message_id。
      (while keep
        (let ((batch (append (plist-get
                              (telega--getChatHistory chat from-id 0 100)
                              :messages)
                             nil)))
          (if (null batch)
              (setq keep nil)
            (dolist (msg batch)
              (if (> (plist-get msg :id) last-read)
                  (push msg msgs)
                (setq keep nil)))
            (when keep
              (setq from-id (plist-get (car (last batch)) :id))))))
      (unless msgs
        (user-error "没有取到未读消息"))
      (let ((buf (generate-new-buffer (format "*telega unread: %s*" title))))
        (with-current-buffer buf
          (org-mode)
          (dolist (msg msgs)
            (let ((sender (ignore-errors
                            (telega-msg-sender-title (telega-msg-sender msg))))
                  (text (telega-msg-content-text msg)))
              (when (and text (not (string-empty-p (string-trim text))))
                (insert (format "%s: %s\n\n" (or sender "?") text)))))
          (when (= (point-min) (point-max))
            (user-error "未读消息里没有可总结的文本内容"))
          (goto-char (point-min)))
        (pop-to-buffer buf)
        (if (eq +telega-summary-engine 'grok)
            (+telega--grok-summarize buf)
          (+gptel-rewrite-region-or-buffer +telega-unread-summary-prompt)))))

  :custom-face
  (telega-msg-heading ((t (:inherit hl-line :background unspecified))))
  (telega-msg-inline-reply ((t (:inherit (hl-line font-lock-function-name-face)))))
  (telega-msg-inline-forward ((t (:inherit (hl-line font-lock-type-face)))))
  (telega-msg-self-title ((t (:bold t :italic t))))
  :bind (:map telega-chat-button-map
              ("h" . nil)
              :map telega-root-mode-map
              ("A" . +telega-toggle-archive)
              ;; 复用全局总结键的肌肉记忆：在 chatbuf 里 C-c r s 直接
              ;; 总结当前聊天的全部未读消息
              :map telega-chat-mode-map
              ("C-c r s" . +telega-summarize-unread))
  :hook ((telega-chat-mode . corfu-mode)
         (telega-chat-mode . telega-completions-setup-capf))
  :config
  (setq telega-chat-show-avatars nil
        telega-user-show-avatars nil
        telega-root-show-avatars nil
        telega-completions-username-show-avatars nil
        telega-active-locations-show-avatars nil
        telega-avatar-text-function (lambda (&rest _) "")

        telega-translate-to-language-by-default "zh"
        telega-chat-input-markups '(nil "org")
        telega-server-libs-prefix (expand-file-name "~/.local")

        ;; root page
        telega-chat-button-width '(0.2 10 25)
        telega-brackets '(((chat (return t)) "" "")
                          ((user (return t)) "" ""))
        telega-chat-button-format-plist (list :with-title 'full-name
                                              :with-username-p nil
                                              :with-title-faces-p nil
                                              :with-unread-trail-p t
                                              :with-members-trail-p nil
                                              :with-bot-verification-p nil
                                              :with-status-icons-trail-p t)

        ;; emoji
        telega-symbol-pin "%"
        telega-symbol-folder ""
        telega-symbol-photo ""

        ;; filters
        telega-filters-custom nil
        telega-filter-custom-show-folders nil

        ;; images
        ;; 上游关闭图片走纯文字风格；本地打开，照片/视频缩略图/网页
        ;; 预览图直接显示（emoji 仍用字体渲染，头像保持关闭）。
        telega-use-images t
        telega-emoji-use-images nil
        telega-symbols-emojify '()

        telega-date-format-alist '((today . "%H:%M") (this-week . "%m/%d") (old . "%m/%d") (date . "%y/%m/%d")
                                   (time . "%H:%M") (date-time . "%y/%m/%d. %H:%M") (date-long . "%y/%m/%d")
                                   (date-break-bar . "%m/%d"))
        telega-chat-group-messages-timespan 600
        telega-completions-capf-functions '(telega-capf-username
                                            telega-capf-hashtag
                                            telega-capf-markdown-precode
                                            telega-capf-botcmd))

  ;; `telega-server-build' runs `make server-reinstall' in
  ;; `telega--lib-directory'.  With straight that is build/telega/, which
  ;; historically lacked Makefile/server/; point builds at the git repo.
  (defadvice! +telega-server-build-from-repo-a (fn &rest args)
    :around #'telega-server-build
    (let* ((src (+telega--server-src-directory))
           (telega--lib-directory (or src telega--lib-directory)))
      (unless (and telega--lib-directory
                   (file-exists-p (expand-file-name "Makefile"
                                                    telega--lib-directory)))
        (user-error
         "telega Makefile not found (looked in %s).  \
Update straight recipe files or run make from straight/repos/telega.el"
         telega--lib-directory))
      (apply fn args)))

  ;; `telega-proxies' is obsolete since telega 0.8.621; proxies are now added
  ;; from `telega-before-auth-hook' via `telega--addProxy'.
  (when (eq system-type 'gnu/linux)
    (add-hook 'telega-before-auth-hook
              (lambda ()
                (telega--addProxy
                    '(:server "127.0.0.1" :port 7891
                              :type (:@type "proxyTypeSocks5"))
                  :enable-p 'enable :comment "local socks5"))))

  ;; Do not redef telega-completions--bot-commands: package already uses
  ;; mapcan (telega-completions.el).  Local copy was checkout-drift; MERGE
  ;; LOCK: do not reintroduce a frozen redef when syncing roife.

  ;; HACK: Show full name only in chatbuf
  (defadvice! +telega-message-header-username-only-a
    (orig msg &optional msg-chat msg-sender addon-inserter)
    :around #'telega-ins--message-header
    (let* ((msg (copy-sequence msg))
           (orig-ins (symbol-function 'telega-ins--msg-sender)))
      (setq msg (plist-put msg :author_signature nil))
      (setq msg (plist-put msg :sender_tag nil))
      (setq msg (plist-put msg :sender_boost_count 0))
      (cl-letf (((symbol-function 'telega-ins--msg-sender)
                 (lambda (sender &rest _args)
                   (funcall orig-ins sender
                            :with-title 'full-name
                            :with-username-p nil
                            :with-badges-p nil)))
                ((symbol-function 'telega-chat-admin-get)
                 (lambda (&rest _) nil)))
        (funcall orig msg msg-chat msg-sender addon-inserter))))

  ;; HACK: show stickers
  (defadvice! +telega-enable-image-for-stickers (orig-fn &rest args)
    :around '(telega-sticker--create-image
              telega-describe-stickerset
              telega-ins--sticker-list
              telega-ins--sticker-image
              telega-ins--inline-sticker
              telega-chatbuf-sticker-insert)
    (let ((telega-use-images t))
      (apply orig-fn args)))

  ;; HACK: disable sponsored msg
  (defadvice! +telega-hide-sponsored-messages-a (&rest _)
    :override #'telega-chatbuf-footer-ins-sponsored-messages
    nil)

  (add-hook! telega-ready-hook
    (defun +telega-disable-sponsored-messages-h ()
      (telega--toggleHasSponsoredMessagesEnabled nil)))

  ;; HACK: remove filter line in main filter
  (defadvice! +telega-hide-default-filter-footer-a (orig-fn &rest args)
    :around #'telega-filters--footer
    (if (and (telega-filter-default-p)
             (not telega--sort-criteria)
             (not telega--sort-inverted))
        ""
      (apply orig-fn args)))

  ;; HACK: preview stickers with vertico
  (defadvice! +telega-stickerset-preview-with-vertico-a (fn &rest args)
    :around #'telega-stickerset--minibuf-post-command
    (cl-letf (((symbol-function #'completion-all-sorted-completions)
               (lambda (&rest _)
                 (list (vertico--candidate)))))
      (apply fn args)))
  )


(use-package telega-dired-dwim
  :straight nil
  :after telega
  :demand t)

;; [chirp] twitter client
(use-package chirp
  :straight (:host github :repo "LuciusChen/chirp")
  :commands (chirp-home
             chirp-following
             chirp-bookmarks
             chirp-likes
             chirp-me
             chirp-list
             chirp-search
             chirp-thread
             chirp-profile
             chirp-profile-followers
             chirp-profile-following-users)
  :config
  (setq chirp-show-avatars nil
        chirp-show-tweet-media nil
        chirp-tweet-separator ""
        chirp-tweet-separator-indent 0))
