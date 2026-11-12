;;; -*- lexical-binding: t -*-

;; Local mail reader. Upstream stopped at Himalaya mode hooks and does not
;; load a mail client. mu and mu4e come from the same Nix package (the
;; `mu4e' output); do not clone djcb/mu with straight or the binary and
;; Elisp versions diverge.
;;
;; Addresses stay in gitignored private.el:
;;   (setq +mu4e-gmail-address "you@gmail.com"
;;         +mu4e-qq-address "you@qq.com"
;;         +mu4e-full-name "Your Name")
;; Sync and SMTP passwords stay in the Keychain, not here.

(defvar +mu4e-gmail-address nil
  "Gmail address for the mu4e gmail context. Set in private.el.")

(defvar +mu4e-qq-address nil
  "QQ address for the mu4e qq context. Set in private.el.")

(defvar +mu4e-full-name nil
  "Display name used by mu4e contexts. Set in private.el.")

(let ((file (expand-file-name "private.el" user-emacs-directory)))
  (when (file-exists-p file)
    (load file nil 'nomessage)))

(defun +mu4e-address-p (address)
  "Return non-nil when ADDRESS is a non-empty string."
  (and (stringp address) (not (string-empty-p address))))

(defun +mu4e-program (name)
  "Return the absolute path of NAME, or NAME when it is not installed yet."
  (or (executable-find name) name))

(defun +set-msmtp-account ()
  "Select the msmtp account from the From header."
  (when (message-mail-p)
    (let* ((from (save-restriction
                   (message-narrow-to-headers)
                   (message-fetch-field "from")))
           (account (cond
                     ((and (+mu4e-address-p +mu4e-gmail-address)
                           from
                           (string-match-p (regexp-quote +mu4e-gmail-address) from))
                      "gmail")
                     ((and (+mu4e-address-p +mu4e-qq-address)
                           from
                           (string-match-p (regexp-quote +mu4e-qq-address) from))
                      "qq"))))
      (when account
        (setq message-sendmail-extra-arguments (list "-a" account))))))

(defun +mu4e-make-context (name address vars)
  "Build a mu4e context named NAME for ADDRESS with extra VARS."
  (make-mu4e-context
   :name name
   :enter-func (lambda () (mu4e-message "Enter %s context" name))
   :leave-func (lambda () (mu4e-message "Leave %s context" name))
   :match-func (lambda (msg)
                 (when msg
                   (mu4e-message-contact-field-matches msg :to address)))
   :vars (append `((user-mail-address . ,address)
                   (user-full-name . ,(or +mu4e-full-name "")))
                 vars)))

(defun +mu4e-split-view-sensibly (&rest _)
  "Use a side-by-side view only when the window is wide enough.

`vertical' puts the headers on the left. `horizontal' keeps them on top.
The cutoff is `split-width-threshold', the same value roife leaves at the
Emacs default."
  (setq mu4e-split-view
        (if (>= (window-body-width) split-width-threshold)
            'vertical
          'horizontal)))

(defun +mu4e-apply ()
  "Apply the local mu4e settings. Safe to call again after private.el changes."
  (require 'message)
  (require 'smtpmail)
  (setopt mu4e-mu-binary (+mu4e-program "mu")
          mu4e-get-mail-command (format "%s -a" (+mu4e-program "mbsync"))
          mu4e-update-interval 300
          mu4e-attachment-dir "~/Desktop"
          mu4e-change-filenames-when-moving t
          message-kill-buffer-on-exit t
          send-mail-function #'message-send-mail-with-sendmail
          message-send-mail-function #'message-send-mail-with-sendmail
          sendmail-program (+mu4e-program "msmtp")
          message-sendmail-envelope-from 'header
          mu4e-use-fancy-chars t
          mu4e-context-policy 'pick-first
          mu4e-compose-context-policy 'ask
          mu4e-maildir-shortcuts
          '((:maildir "/gmail/INBOX" :key ?g)
            (:maildir "/qq/INBOX" :key ?q)))
  (setq mu4e-headers-thread-single-orphan-prefix '("─>" . "─▶")
        mu4e-headers-thread-orphan-prefix '("┬>" . "┬▶ ")
        mu4e-headers-thread-connection-prefix '("│ " . "│ ")
        mu4e-headers-thread-first-child-prefix '("├>" . "├▶")
        mu4e-headers-thread-child-prefix '("├>" . "├▶")
        mu4e-headers-thread-last-child-prefix '("└>" . "╰▶")
        mu4e-headers-unread-mark '("u" . "📩 ")
        mu4e-headers-draft-mark '("D" . "🚧 ")
        mu4e-headers-flagged-mark '("F" . "🚩 ")
        mu4e-headers-new-mark '("N" . "✨ ")
        mu4e-headers-passed-mark '("P" . "↪ ")
        mu4e-headers-replied-mark '("R" . "↩ ")
        mu4e-headers-seen-mark '("S" . " ")
        mu4e-headers-trashed-mark '("T" . "🗑️ ")
        mu4e-headers-attach-mark '("a" . "📎 ")
        mu4e-headers-encrypted-mark '("x" . "🔑 ")
        mu4e-headers-signed-mark '("s" . "🖊 ")
        mu4e-headers-list-mark '("l" . "🔈 ")
        mu4e-headers-personal-mark '("p" . "👨 ")
        mu4e-headers-calendar-mark '("c" . "📅 ")
        mu4e-contexts
        (delq nil
              (list
               (when (+mu4e-address-p +mu4e-gmail-address)
                 (+mu4e-make-context
                  "gmail" +mu4e-gmail-address
                  ;; Gmail IMAP keeps these names even when the web UI is Chinese.
                  '((mu4e-drafts-folder . "/gmail/[Gmail]/Drafts")
                    (mu4e-refile-folder . "/gmail/[Gmail]/All Mail")
                    (mu4e-sent-folder . "/gmail/[Gmail]/Sent Mail")
                    (mu4e-trash-folder . "/gmail/[Gmail]/Trash"))))
               (when (+mu4e-address-p +mu4e-qq-address)
                 (+mu4e-make-context
                  "qq" +mu4e-qq-address
                  '((mu4e-drafts-folder . "/qq/Drafts")
                    (mu4e-refile-folder . "/qq/Archive")
                    (mu4e-sent-folder . "/qq/Sent Messages")
                    (mu4e-trash-folder . "/qq/Deleted Messages")))))))
  (add-hook 'message-send-mail-hook #'+set-msmtp-account)
  (advice-add #'mu4e-display-buffer :before #'+mu4e-split-view-sensibly)
  (add-to-list 'display-buffer-alist
               '("\\*mu4e-update\\*"
                 (display-buffer-below-selected)
                 (window-height . 0.1))))

;; `use-package' is an autoload in Emacs 31, so `fboundp' is true even
;; under emacs -Q. Batch tests apply the settings at load time. A normal
;; session defers them until `mu4e' is invoked. If the Nix output is not
;; on `load-path' yet, do nothing so startup still succeeds.
(defun +mu4e--prefix (path)
  "Return the installation prefix that contains PATH's bin directory."
  (file-name-directory (directory-file-name (file-name-directory path))))

(defun +mu4e-lisp-dir ()
  "Find mu4e.el next to the Nix profile link for `mu', not the bare store bin.

nix-darwin's user profile links `bin/mu' but not `share/emacs'. The
home-manager path that the symlink points at still has both."
  (let ((path (executable-find "mu"))
        (dir nil))
    (while (and path (not dir))
      (let ((candidate (expand-file-name "share/emacs/site-lisp/mu4e"
                                         (+mu4e--prefix path))))
        (if (file-exists-p (expand-file-name "mu4e.el" candidate))
            (setq dir candidate)
          (let ((link (file-symlink-p path)))
            (setq path (and link
                            (expand-file-name link (file-name-directory path))))))))
    dir))

(when-let ((dir (+mu4e-lisp-dir)))
  (add-to-list 'load-path dir))

(cond
 ((not (locate-library "mu4e"))
  nil)
 (noninteractive
  (require 'mu4e)
  (+mu4e-apply))
 (t
  (use-package mu4e
    :commands (mu4e)
    :config
    (+mu4e-apply))))
