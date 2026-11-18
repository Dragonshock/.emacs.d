;; -*- lexical-binding: t; -*-
(use-package telega
  :straight (:host github :repo "zevlg/telega.el"
                   :files (:defaults "contrib/*.el" "etc"))
  :require-incrementally
  (password-cache cl-lib find-func emacsbug
                  telega-customize telega-server telega-root telega-ins
                  telega-match telega-filter telega-chat telega-folders
                  telega-user telega-info telega-media telega-sticker
                  telega-util telega-vvnote telega-webpage telega-notifications
                  telega-modes telega-i18n telega-story telega-completions
                  telega-tdlib telega-tdlib-events t)
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

  (defun +telega-reaction-emoji (emoji)
    "Return EMOJI, using the emoji presentation for a plain heart."
    (if (equal emoji "❤") "❤️" emoji))

  (defun +telega-reaction-title (title)
    "Use the emoji presentation when TITLE starts with a plain heart."
    (if (and (stringp title) (string-prefix-p "❤" title))
        (concat "❤️" (substring title 1))
      title))

  (defun +telega-alert--strip-text-properties (args)
    "Strip text properties from the notification spec in ARGS.
`alert' embeds the title and body in a notifier string, where Emacs
text properties are invalid."
    (let ((notify-spec (copy-sequence (car args))))
      (dolist (key '(:title :body))
        (let ((text (plist-get notify-spec key)))
          (when (stringp text)
            (setq notify-spec
                  (plist-put notify-spec key
                             (substring-no-properties text))))))
      (list notify-spec)))

  (defun +telega-save-file-to-clipboard (msg)
    "Save the file attached to MSG onto the system clipboard."
    (interactive (list (telega-msg-for-interactive)))
    (let ((file (telega-msg--content-file msg)))
      (unless file
        (user-error "No file associated with message"))
      (telega-file--download file
        :priority 32
        :update-callback
        (lambda (dfile)
          (telega-msg-redisplay msg)
          (when (telega-file--downloaded-p dfile)
            (let* ((fpath (telega-file--path dfile))
                   (command
                    (if (eq system-type 'darwin)
                        (list "osascript" "-e"
                              (format "set the clipboard to POSIX file %S" fpath))
                      (list "sh" "-c" (format "wl-copy < %s" (shell-quote-argument fpath))))))
              (make-process
               :name "telega-clipboard"
               :buffer nil
               :command command)))))))

  (defun +telega-msg-save-to-cloud-copyleft (msg)
    "Send the file attached to MSG to Saved Messages."
    (interactive (list (telega-msg-for-interactive)))
    (let ((file (telega-msg--content-file msg)))
      (unless file
        (user-error "No file associated with message"))
      (telega-file--download file
        :priority 32
        :update-callback
        (lambda (dfile)
          (telega-msg-redisplay msg)
          (when (telega-file--downloaded-p dfile)
            (let* ((fpath (telega-file--path dfile))
                   (ifile (telega-chatbuf--gen-input-file fpath 'Document)))
              (telega--sendMessage
               (telega-chat-me t)
               (list :@type "inputMessageDocument"
                     :document (list :@type "inputDocument"
                                     :document ifile)
                     :caption (telega-fmt-text "#copyleft")))
              (message "Saved to cloud: %s" (file-name-nondirectory fpath))))))))

  (defun +telega-redraw-for-theme (&rest _)
    "Redraw telega buffers so palette colors follow the enabled theme."
    (when (and (boundp 'telega-root-buffer-name)
               (get-buffer telega-root-buffer-name))
      (telega-root-view--redisplay)
      (dolist (chatbuf (telega-chat-buffers))
        (with-current-buffer chatbuf
          (when telega-chatbuf--ewoc
            (with-telega-buffer-modify
             (telega-save-cursor
               (telega-chatbuf--footer-update)
               (ewoc-refresh telega-chatbuf--ewoc))))))))

  :init
  ;; Read while the other image options take their defaults.
  (setq telega-use-images nil)
  :custom-face
  (telega-msg-heading ((t (:inherit hl-line :background unspecified))))
  (telega-msg-inline-reply ((t (:inherit (hl-line font-lock-function-name-face)))))
  (telega-msg-inline-forward ((t (:inherit (hl-line font-lock-type-face)))))
  (telega-msg-self-title ((t (:bold t :italic t))))
  :bind (:map telega-chat-button-map
              ("h" . nil)
              :map telega-root-mode-map
              ("A" . +telega-toggle-archive)
              :map telega-prefix-map
              ("p" . telega-chatbuf-filter-search)
              ("d" . telega-chat-remove-member)
              ("m" . telega-describe-chat-members)
              :map telega-msg-button-map
              ("C" . +telega-save-file-to-clipboard)
              ("s" . +telega-msg-save-to-cloud-copyleft))
  :hook ((telega-chat-mode . corfu-mode)
         (telega-chat-mode . +telega-completions-setup-capf))
  :config
  (setq telega-root-fill-column 70
        telega-chat-fill-column 90)

  (add-hook! telega-chat-mode-hook
    (defun +telega-disable-visual-fill-column-h ()
      "Disable visual fill column in Telega chat buffers."
      (visual-fill-column-mode -1)))

  (telega-root-auto-fill-mode -1)
  (remove-hook 'telega-chat-mode-hook #'telega-chat-auto-fill-mode)

  (setq telega-chat-show-avatars nil
        telega-user-show-avatars nil
        telega-root-show-avatars nil
        telega-completions-username-show-avatars nil
        telega-active-locations-show-avatars nil
        telega-avatar-text-function (lambda (&rest _) "")

        telega-translate-to-language-by-default "zh"
        telega-chat-input-markups '("markdown2" "org")
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
        ;; Avoid Telega's explicit `compose-chars' strings.
        telega-topic-brackets '("⟦" "⟧")
        telega-symbol-forward "→"
        telega-symbol-story-reply "↩"

        ;; filters
        telega-filters-custom nil
        telega-filter-custom-show-folders nil

        ;; images.  `telega-use-images' is set in :init, before these
        ;; options take their defaults.
        telega-emoji-use-images nil
        telega-symbols-emojify
        (cl-reduce (lambda (emojify key)
                     (assq-delete-all key emojify))
                   '(checkmark heavy-checkmark button-close)
                   :initial-value (copy-sequence
                                   (default-value 'telega-symbols-emojify)))

        telega-date-format-alist '((today . "%H:%M") (this-week . "%m/%d") (old . "%m/%d") (date . "%y/%m/%d")
                                   (time . "%H:%M") (date-time . "%y/%m/%d. %H:%M") (date-long . "%y/%m/%d")
                                   (date-break-bar . "%m/%d"))
        telega-chat-group-messages-timespan 600
        telega-completions-capf-functions '(telega-capf-username
                                            telega-capf-hashtag
                                            telega-capf-markdown-precode
                                            telega-capf-botcmd))

  (defun +telega-capf-in-input (capf)
    "Call CAPF only while point is in Telega's writable input area."
    (when (and (markerp telega-chatbuf--input-marker)
               (>= (point) telega-chatbuf--input-marker)
               (not (get-text-property (point) 'read-only)))
      (funcall capf)))

  (defun +telega-completions-setup-capf ()
    "Set up Telega CAPFs without completing read-only message text."
    (telega-completions-setup-capf)
    (setq-local completion-at-point-functions
                (mapcar (lambda (capf)
                          (apply-partially #'+telega-capf-in-input capf))
                        telega-completions-capf-functions)))

  (when (eq system-type 'gnu/linux)
    (add-hook! telega-before-auth-hook
      (defun +telega-enable-linux-proxy-h ()
        "Add and enable the local SOCKS5 proxy before Telega authorizes."
        (telega--addProxy '(:server "127.0.0.1" :port 7891 :type (:@type "proxyTypeSocks5"))
          :enable-p t
          :comment "Local SOCKS5 proxy"))))

  ;; HACK: Work around upstream bot command completion returning nested lists.
  ;; Each mapped candidate list is freshly allocated, so `mapcan' is safe here.
  (defun telega-completions--bot-commands (chat)
    "Return bot command completion candidates for CHAT."
    (let* ((info (telega-chat--info chat))
           (telega-full-info-offline-p nil)
           (full-info (telega--full-info info)))
      (if (telega-chatbuf-match-p '(type bot))
          (telega-completions--bot-commands-list
           (telega--tl-get full-info :bot_info :commands))
        (mapcan (lambda (bot-commands)
                  (telega-completions--bot-commands-list
                   (plist-get bot-commands :commands)
                   (telega-msg-sender-username
                    (telega-user-get
                     (plist-get bot-commands :bot_user_id))
                    'with-@)))
                (plist-get full-info :bot_commands)))))

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

  ;; Lucius-style chat chrome.  His Matrix bridge, notification keyword
  ;; filter, and nerd-icons symbols are not copied: the bridge data is
  ;; personal, and nerd-icons is not part of this telega install.
  (keymap-global-set "C-c t" telega-prefix-map)
  (setq telega-autoplay-mode t
        telega-notifications-mode t
        telega-open-file-function #'org-open-file
        telega-sticker-size '(6 . 24)
        telega-symbol-mark (propertize " " 'face 'telega-button-highlight)
        telega-msg-save-dir "~/Downloads"
        telega-root-default-view-function 'telega-view-folders
        telega-chat-folders-insexp (lambda () nil)
        telega-symbol-rich-text-table-border '(?─ ?\s ?\s)
        telega-builtin-palettes-alist
        '((light
           ((:outline "#b4637a") (:foreground "#b4637a") (:background "#d1c7c7"))
           ((:outline "#ea9d34") (:foreground "#ea9d34") (:background "#d1ccc7"))
           ((:outline "#907aa9") (:foreground "#907aa9") (:background "#cdc7d1"))
           ((:outline "#568D68") (:foreground "#568D68") (:background "#c7d1c7"))
           ((:outline "#286983") (:foreground "#286983") (:background "#cacfcf"))
           ((:outline "#56949f") (:foreground "#56949f") (:background "#c6cbd1"))
           ((:outline "#d7827e") (:foreground "#d7827e") (:background "#d1c7cb")))
          (dark
           ((:outline "#eb6f92") (:foreground "#eb6f92") (:background "#3d2828"))
           ((:outline "#f6c177") (:foreground "#f6c177") (:background "#2c2620"))
           ((:outline "#b294bb") (:foreground "#b294bb") (:background "#2e1e2e"))
           ((:outline "#95b1ac") (:foreground "#95b1ac") (:background "#1e2e1e"))
           ((:outline "#81a2be") (:foreground "#81a2be") (:background "#234242"))
           ((:outline "#9ccfd8") (:foreground "#9ccfd8") (:background "#1e262e"))
           ((:outline "#ebbcba") (:foreground "#ebbcba") (:background "#470528"))))
        telega-box-button-styles
        (let ((styles (copy-tree telega-box-button-styles)))
          (dolist (tag '(owner-sender-tag admin-sender-tag))
            (plist-put (alist-get tag styles) :passive-face 'telega-shadow))
          styles))
  (add-hook 'enable-theme-functions #'+telega-redraw-for-theme)
  (add-hook 'telega-msg-ignore-predicates
            (telega-match-gen-predicate 'msg '(sender is-blocked)))
  (advice-add 'telega-ins--msg-reaction-type :around
              (lambda (fn rt)
                (if (eq (intern (plist-get rt :@type)) 'reactionTypeEmoji)
                    (telega-ins (+telega-reaction-emoji (plist-get rt :emoji)))
                  (funcall fn rt))))
  (advice-add 'telega-msg-reaction-title-for-completion :filter-return
              #'+telega-reaction-title)
  (require 'telega-mnz)
  (global-telega-mnz-mode 1)
  (when (eq system-type 'darwin)
    (require 'telega-alert)
    (advice-add 'telega-alert--notify :filter-args
                #'+telega-alert--strip-text-properties)
    (telega-alert-mode 1))
  )


(use-package telega-dired-dwim
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
  :init
  (setq chirp-cache-directory (no-littering-expand-var-file-name "chirp/")
        chirp-compose-temporary-directory
        (no-littering-expand-var-file-name "chirp/compose/"))
  (make-directory chirp-cache-directory t)
  (make-directory chirp-compose-temporary-directory t)
  :config
  (setq chirp-show-avatars nil
        chirp-show-tweet-media nil
        chirp-tweet-separator ""
        chirp-tweet-separator-indent 0))
