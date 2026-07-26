;; -*- lexical-binding: t; -*-
(use-package telega
  :straight (:host github :repo "zevlg/telega.el"
                   :files (:defaults "contrib/*.el" "etc"))
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

  (defun +telega-toggle-archive ()
    "Toggle telega root buffer between the main and archive filters."
    (interactive)
    (let* ((archive-p (equal (telega-filter-active) '(archive)))
           (filter (if archive-p (list telega-filter-default) '(archive))))
      (telega-filters-push filter)
      (message "telega filter: %s" (if archive-p telega-filter-default 'archive))))

  (defun +telega-summarize-unread ()
    "汇集当前聊天的全部未读消息，交给 `+gptel-rewrite-summarize' 总结。
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
          (text-mode)
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
        (+gptel-rewrite-summarize))))

  :custom-face
  (telega-msg-heading ((t (:inherit hl-line :background unspecified))))
  (telega-msg-inline-reply ((t (:inherit (hl-line font-lock-function-name-face)))))
  (telega-msg-inline-forward ((t (:inherit (hl-line font-lock-type-face)))))
  (telega-msg-user-title ((t (:bold t))))
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

  ;; `telega-proxies' is obsolete since telega 0.8.621; proxies are now added
  ;; from `telega-before-auth-hook' via `telega--addProxy'.
  (when (eq system-type 'gnu/linux)
    (add-hook 'telega-before-auth-hook
              (lambda ()
                (telega--addProxy
                    '(:server "127.0.0.1" :port 7891
                              :type (:@type "proxyTypeSocks5"))
                  :enable-p 'enable :comment "local socks5"))))

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

  ;; HACK: workaround with beginend
  (with-eval-after-load 'beginend
    (defun beginend-telega-mode-goto-beginning ()
      "Go to the first button in the Telega root view."
      (interactive)
      (beginend--double-tap-begin
       (goto-char (max (point-min)
                       (1- telega-root-view--ewocs-marker)))
       (telega-button-forward 1 nil 'no-error)))

    (defun beginend-telega-mode-goto-end ()
      "Go to the last button in the Telega root view."
      (interactive)
      (beginend--double-tap-end
       (telega-button-backward 1 nil 'no-error)))

    (defvar beginend-telega-mode-map
      (let ((map (make-sparse-keymap)))
        (beginend--defkey map
                          #'beginend-telega-mode-goto-beginning
                          #'beginend-telega-mode-goto-end)
        map)
      "Keymap for `beginend-telega-mode'.")

    (define-minor-mode beginend-telega-mode
      "Make buffer boundary commands aware of the Telega root view."
      :lighter " be"
      :keymap beginend-telega-mode-map)

    (add-to-list 'beginend-modes
                 '(telega-root-mode-hook . beginend-telega-mode)))
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
