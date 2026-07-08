;; -*- lexical-binding: t; -*-
;; (use-package language-detection
;;   :straight t)

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

  :custom-face
  (telega-msg-heading ((t (:inherit hl-line :background unspecified))))
  (telega-msg-inline-reply ((t (:inherit (hl-line font-lock-function-name-face)))))
  (telega-msg-inline-forward ((t (:inherit (hl-line font-lock-type-face)))))
  (telega-msg-user-title ((t (:bold t))))
  :bind (:map telega-chat-button-map
              ("h" . nil)
              :map telega-root-mode-map
              ("A" . +telega-toggle-archive))
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
        telega-use-images nil
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

  (when (eq system-type 'gnu/linux)
    (setq telega-proxies '((:server "127.0.0.1" :port 7891 :enable t :type (:@type "proxyTypeSocks5")))))

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
      (apply orig-fn args))))


(use-package telega-dired-dwim
  :straight nil
  :after telega
  :demand t)
