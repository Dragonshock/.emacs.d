;;; -*- lexical-binding: t -*-

;; Batch checks for the upstream-sync edits.  Run from the repo root:
;;   emacs -Q --batch -l scripts/test-upstream-sync.el
;; Each check prints "PASS" or "FAIL".  The process exits non-zero
;; when any check fails.  Nothing here loads the running config, so it
;; does not touch the Rime database.

(defvar +test-failures nil)

(defmacro +test (name &rest body)
  `(let ((err (condition-case e
                  (progn ,@body nil)
                (error e))))
     (if err
         (progn (push ,name +test-failures)
                (princ (format "FAIL %s: %S\n" ,name err)))
       (princ (format "PASS %s\n" ,name)))))

(defconst +repo (expand-file-name ".." (file-name-directory load-file-name)))

(defun +read (relative)
  (with-temp-buffer
    (insert-file-contents (expand-file-name relative +repo))
    (buffer-string)))

(defun +form-between (text start-re end-re)
  "Return TEXT from START-RE up to, but not including, END-RE."
  (let ((start (string-match start-re text)))
    (unless start (error "start %s not found" start-re))
    (let ((end (string-match end-re text (1+ start))))
      (unless end (error "end %s not found" end-re))
      (substring text start end))))

;; --------------------------------------------------------------- agenda

(+test "agenda org form drops the built-in straight recipe"
  (let ((form (+form-between (+read "core/init-agenda.el")
                             "(use-package org\n"
                             "\n(use-package ")))
    (when (string-match-p ":straight (:type built-in)" form)
      (error "built-in straight recipe still present"))
    (when (string-match-p ":straight" form)
      (error "straight keyword still present on the first org form"))
    (unless (string-match-p "org-todo-keywords" form)
      (error "org form body missing"))
    (unless (string-match-p "org-deadline-warning-days 3" form)
      (error "org form body changed"))
    (unless (string-match-p "\\+org-set-project-archive-location" form)
      (error "archive helper missing"))))

;; ---------------------------------------------------------------- shell

(+test "eshell aliases live in Lisp and are not written out"
  (let* ((text (+read "core/init-shell.el"))
         (setq-block (+form-between text "(setq\n" "(defun \\+eshell-toggle")))
    (unless (string-match-p "Aliases are defined below in Lisp" setq-block)
      (error "missing comment that aliases are defined below in Lisp"))
    ;; The setq closes on this line, so the form is `eshell-aliases-file nil)'.
    (unless (string-match-p "^[ \t]*eshell-aliases-file nil)?$" setq-block)
      (error "eshell-aliases-file is not nil in the eshell setq"))
    (when (string-match-p "eshell-write-aliases-list :override" text)
      (error "advice still overrides eshell-write-aliases-list"))
    (when (string-match-p "Don't auto-write our aliases" text)
      (error "old auto-write comment still present"))
    (unless (string-match-p "(defun \\+eshell-toggle" text)
      (error "+eshell-toggle missing"))
    (unless (string-match-p "display-buffer-alist" text)
      (error "display-buffer-alist workaround missing"))
    (unless (string-match-p "display-comint-buffer-action" text)
      (error "comint display workaround comment missing"))))

;; ------------------------------------------------------------ modeline

(+test "breadcrumb lengths are 0.5 and 0.45"
  (let ((form (+form-between (+read "core/init-modeline.el")
                             "(use-package breadcrumb"
                             "\n;; \\[tab-bar\\]")))
    (unless (string-match-p
             "The short prefix in breadcrumb.el expands to `breadcrumb-'"
             form)
      (error "bc- prefix comment missing"))
    (unless (string-match-p "^[ \t]*breadcrumb-project-max-length 0\\.5$" form)
      (error "project max length is not 0.5"))
    (unless (string-match-p "^[ \t]*breadcrumb-imenu-max-length 0\\.45$" form)
      (error "imenu max length is not 0.45"))))

;; ------------------------------------------------------- stayed source

(+test "global-kkp-mode stayed in init-xterm"
  (unless (string-match-p "global-kkp-mode" (+read "core/init-xterm.el"))
    (error "global-kkp-mode missing")))

(+test "flymake single-diagnostic advice stayed"
  (unless (string-match-p "\\+flymake-show-buffer-diagnostics-single-a"
                          (+read "core/init-prog.el"))
    (error "advice function missing")))

(+test "emureader use-package stayed"
  (unless (string-match-p "(use-package emureader" (+read "core/init-tools.el"))
    (error "use-package emureader missing")))

(+test "org-fragtog-mode stayed"
  (unless (string-match-p "org-fragtog-mode" (+read "core/init-org.el"))
    (error "org-fragtog-mode missing")))

(+test "file-name-handler-alist stayed in early-init"
  (unless (string-match-p "file-name-handler-alist" (+read "early-init.el"))
    (error "file-name-handler-alist missing")))

(+test "main org form still has :straight t"
  (let ((form (+form-between (+read "core/init-org.el")
                             "(use-package org\n"
                             "\n(use-package ")))
    (unless (string-match-p ":straight t" form)
      (error "main org form lost :straight t"))))

;; ------------------------------------------------------------ behavior

(+test "nil eshell-aliases-file does not create a file"
  (require 'em-alias)
  (let ((eshell-aliases-file nil)
        (eshell-command-aliases-list '(("ll" "ls -la $*"))))
    (unless eshell-command-aliases-list
      (error "alias list is empty"))
    (let ((before-dir (and (file-directory-p eshell-directory-name)
                           (directory-files eshell-directory-name)))
          (before-cwd (directory-files default-directory)))
      (eshell-write-aliases-list)
      (unless (equal before-dir
                     (and (file-directory-p eshell-directory-name)
                          (directory-files eshell-directory-name)))
        (error "eshell directory changed"))
      (unless (equal before-cwd (directory-files default-directory))
        (error "working directory gained or lost a file")))))

(+test "a path in eshell-aliases-file does create a file"
  (require 'em-alias)
  (let* ((dir (make-temp-file "eshell-alias-test" t))
         (path (expand-file-name "alias" dir))
         (eshell-aliases-file path)
         (eshell-command-aliases-list '(("ll" "ls -la $*"))))
    (unwind-protect
        (progn
          (eshell-write-aliases-list)
          (unless (file-exists-p path)
            (error "negative control did not create %s" path)))
      (delete-directory dir t))))

(+test "breadcrumb length options are bound"
  (load (expand-file-name "straight/repos/breadcrumb/breadcrumb.el" +repo) nil t)
  (unless (boundp 'breadcrumb-project-max-length)
    (error "breadcrumb-project-max-length is not bound"))
  (unless (boundp 'breadcrumb-imenu-max-length)
    (error "breadcrumb-imenu-max-length is not bound")))

(when +test-failures
  (princ (format "\n%d failed\n" (length +test-failures)))
  (kill-emacs 1))
(princ "\nall checks passed\n")
