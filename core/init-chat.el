;; -*- lexical-binding: t; -*-
;; (use-package language-detection
;;   :straight t)

(use-package telega
  :straight t
  :preface
  (defun +telega-install-tdlib ()
    "Fetch and install telega's expected TDLib commit under ~/.local."
    (interactive)
    (unless (eq system-type 'darwin)
      (user-error "+telega-install-tdlib currently only supports macOS"))
    (require 'json)
    (require 'telega)
    (require 'url)
    (require 'compile)
    (let* ((version (telega-dockrefile-tdlib-version))
           (prefix (expand-file-name "~/.local"))
           (repos-dir (expand-file-name "repos" prefix))
           (bin-dir (expand-file-name "bin" prefix))
           (lib-dir (expand-file-name "lib" prefix))
           commit td-dir build-dir buffer commands)
      (string-match "\\`\\(.+\\)-\\([[:xdigit:]]+\\)\\'" version)
      (setq commit (match-string 2 version))
      (let ((url-request-extra-headers
             '(("Accept" . "application/vnd.github+json")
               ("User-Agent" . "Emacs"))))
        (with-current-buffer (url-retrieve-synchronously
                              (format "https://api.github.com/repos/tdlib/td/commits/%s" commit))
          (goto-char (point-min))
          (re-search-forward "\r?\n\r?\n")
          (let ((json-object-type 'alist)
                (json-key-type 'symbol))
            (setq commit (alist-get 'sha (json-read))))
          (kill-buffer (current-buffer))))
      (setq td-dir (expand-file-name (format "td-%s" version) repos-dir)
            build-dir (expand-file-name "build" td-dir)
            buffer (get-buffer-create "*telega-install-tdlib*"))
      (when (file-exists-p td-dir)
        (delete-directory td-dir t))
      (make-directory repos-dir t)
      (make-directory bin-dir t)
      (setq commands
            `(("brew" "install" "cmake" "gperf" "openssl@3" "pkg-config")
              ("git" "clone" "--revision" ,commit "https://github.com/tdlib/td.git" ,td-dir)
              ,(lambda ()
                 `("cmake" "-S" ,td-dir "-B" ,build-dir
                   "-DCMAKE_BUILD_TYPE=Release"
                   ,(format "-DCMAKE_INSTALL_PREFIX=%s" prefix)
                   ,(format "-DCMAKE_C_COMPILER=%s"
                            (car (process-lines "xcrun" "-find" "clang")))
                   ,(format "-DCMAKE_CXX_COMPILER=%s"
                            (car (process-lines "xcrun" "-find" "clang++")))
                   ,(format "-DOPENSSL_ROOT_DIR=%s"
                            (car (process-lines "brew" "--prefix" "openssl@3")))))
              ("cmake" "--build" ,build-dir "--target" "install" "--parallel"
               ,(car (process-lines "sysctl" "-n" "hw.physicalcpu")))))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer))
        (compilation-mode))
      (display-buffer buffer)
      (let (next)
        (setq next
              (lambda ()
                (if commands
                    (let ((command (pop commands)))
                      (when (functionp command)
                        (setq command (funcall command)))
                      (with-current-buffer buffer
                        (let ((inhibit-read-only t))
                          (goto-char (point-max))
                          (insert "$ " (mapconcat #'identity command " ") "\n")))
                      (make-process
                       :name "telega-install-tdlib"
                       :buffer buffer
                       :command command
                       :connection-type 'pipe
                       :noquery t
                       :sentinel
                       (lambda (process _event)
                         (when (memq (process-status process) '(exit signal))
                           (if (zerop (process-exit-status process))
                               (funcall next)
                             (with-current-buffer buffer
                               (let ((inhibit-read-only t))
                                 (goto-char (point-max))
                                 (insert (format "%s exited with %s\n"
                                                 (mapconcat #'identity command " ")
                                                 (process-exit-status process)))))
                             (message "TDLib install failed"))))))
                  (dolist (file (directory-files lib-dir t "\\`libtd.*\\.dylib\\'"))
                    (copy-file file (expand-file-name (file-name-nondirectory file) bin-dir) t))
                  (with-current-buffer buffer
                    (let ((inhibit-read-only t))
                      (goto-char (point-max))
                      (insert (format "Installed TDLib %s (%s) into %s\n" version commit prefix))))
                  (message "Installed TDLib %s" version))))
        (funcall next)
        (message "Installing TDLib %s" version))))
  :custom-face
  (telega-msg-heading ((t (:inherit hl-line :background unspecified))))
  (telega-msg-inline-reply ((t (:inherit (hl-line font-lock-function-name-face)))))
  (telega-msg-inline-forward ((t (:inherit (hl-line font-lock-type-face)))))
  (telega-msg-user-title ((t (:bold t))))
  :bind (:map telega-chat-button-map
              ("h" . nil))
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
                                              :with-status-icons-trail-p nil)

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

  (defadvice! +telega-enable-image-for-stickers (orig-fn &rest args)
    :around '(telega-sticker--create-image
              telega-describe-stickerset
              telega-ins--sticker-list
              telega-ins--sticker-image
              telega-ins--inline-sticker
              telega-chatbuf-sticker-insert)
    (let ((telega-use-images t))
      (apply orig-fn args))))


(use-package telega-adblock
  :straight nil
  :after telega
  :hook (telega-chat-mode . telega-adblock-mode))


(use-package telega-dired-dwim
  :straight nil
  :after telega)
