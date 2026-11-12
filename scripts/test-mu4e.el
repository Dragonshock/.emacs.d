;;; -*- lexical-binding: t -*-

;; Repeatable check for core/init-mu4e.el. Does not load init.el or Rime.
;;
;;   emacs -Q --batch -l scripts/test-mu4e.el
;;
;; Same sequence as the agreed acceptance command: fixture, then
;; core/init-mu4e.el, then the context names. Assertions cover the rest.

(defvar +test-failures nil)

(defmacro +test (name &rest body)
  `(let ((err (condition-case e
                  (progn ,@body nil)
                (error e))))
     (if err
         (progn (push ,name +test-failures)
                (princ (format "FAIL %s: %S\n" ,name err)))
       (princ (format "PASS %s\n" ,name)))))

(defconst +repo
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))

(defconst +mu4e-lisp
  (or (getenv "MU4E_LISP")
      "/nix/store/sawfnhdr06sw1ghlhf3iww9mw6z9nrwh-mu-1.14.4-mu4e/share/emacs/site-lisp/mu4e"))

(setq user-emacs-directory (expand-file-name "mu4e-empty/" (temporary-file-directory)))
(make-directory user-emacs-directory t)

(dolist (name '("mu" "mbsync" "msmtp"))
  (let ((path (expand-file-name name "/tmp/mu4e-fake-bin")))
    (make-directory (file-name-directory path) t)
    (unless (file-exists-p path)
      (write-region "" nil path nil 'silent))
    (set-file-modes path #o755)))

(advice-add 'executable-find :around
            (lambda (orig name &rest args)
              (if (member name '("mu" "mbsync" "msmtp"))
                  (expand-file-name name "/tmp/mu4e-fake-bin")
                (apply orig name args))))

(add-to-list 'load-path +mu4e-lisp)

(defun +load-mu4e-config ()
  (load (expand-file-name "core/init-mu4e.el" +repo) nil 'nomessage))

(+test "config file loads"
  (unless (file-exists-p +mu4e-lisp)
    (error "mu4e lisp missing: %s" +mu4e-lisp))
  (+load-mu4e-config))

(+test "empty private.el yields no contexts"
  (unless (null mu4e-contexts)
    (error "contexts: %S" (mapcar #'mu4e-context-name mu4e-contexts))))

(setq +mu4e-gmail-address "reader@example.com"
      +mu4e-qq-address "reader@example.net"
      +mu4e-full-name "Mail Reader")
(+load-mu4e-config)

(+test "contexts are gmail and qq only"
  (let ((names (mapcar #'mu4e-context-name mu4e-contexts)))
    (princ (format "contexts %S\n" names))
    (unless (equal names '("gmail" "qq"))
      (error "names: %S" names))))

(+test "no third-party addresses"
  (let ((blob (prin1-to-string mu4e-contexts)))
    (dolist (addr '("chenyh572@gmail.com"
                    "chenyaohua@njcjh.cn"
                    "chenyh1013@163.com"
                    "roifewu@gmail.com"))
      (when (string-match-p (regexp-quote addr) blob)
        (error "leaked %s" addr)))))

(+test "fetch command is mbsync -a"
  (let* ((cmd mu4e-get-mail-command)
         (program (car (split-string cmd))))
    (unless (and (string-suffix-p "mbsync" program)
                 (member "-a" (split-string cmd)))
      (error "command: %S" cmd))))

(+test "send program is msmtp"
  (unless (string-suffix-p "msmtp" sendmail-program)
    (error "sendmail-program: %S" sendmail-program))
  (unless (eq message-send-mail-function #'message-send-mail-with-sendmail)
    (error "message-send-mail-function: %S" message-send-mail-function)))

(+test "gmail uses IMAP folder names"
  (let* ((gmail (car mu4e-contexts))
         (vars (mu4e-context-vars gmail)))
    (unless (equal (alist-get 'mu4e-sent-folder vars)
                   "/gmail/[Gmail]/Sent Mail")
      (error "sent: %S" (alist-get 'mu4e-sent-folder vars)))))

(+test "inbox shortcuts"
  (let ((dirs (mapcar (lambda (item) (plist-get item :maildir))
                      mu4e-maildir-shortcuts)))
    (unless (equal dirs '("/gmail/INBOX" "/qq/INBOX"))
      (error "shortcuts: %S" dirs))))

(+test "mu4e split follows window width"
  (unless (advice-member-p #'+mu4e-split-view-sensibly #'mu4e-display-buffer)
    (error "advice missing"))
  (let ((width (window-body-width)))
    (let ((split-width-threshold width))
      (+mu4e-split-view-sensibly)
      (unless (eq mu4e-split-view 'vertical)
        (error "wide window chose %S" mu4e-split-view)))
    (let ((split-width-threshold (1+ width)))
      (+mu4e-split-view-sensibly)
      (unless (eq mu4e-split-view 'horizontal)
        (error "narrow window chose %S" mu4e-split-view)))))

(+test "msmtp account follows From"
  (require 'message)
  (with-temp-buffer
    (insert "From: Mail Reader <reader@example.net>\nTo: someone@example.com\n\n")
    (message-mode)
    (+set-msmtp-account)
    (unless (equal message-sendmail-extra-arguments '("-a" "qq"))
      (error "arguments: %S" message-sendmail-extra-arguments))))

(when +test-failures
  (kill-emacs 1))
