;;; -*- lexical-binding: t -*-

;; Batch checks that goggles is commented out of the config.
;;   emacs -Q --batch -l scripts/test-goggles-off.el
;; Does not load init.el, so it does not touch the Rime database.

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

(defconst +highlight (+read "core/init-highlight.el"))

(+test "goggles use-package is not active"
  (when (string-match-p "^[ \t]*(use-package goggles" +highlight)
    (error "uncommented use-package goggles")))

(+test "goggles section header is kept"
  (unless (string-match-p (concat "^" (regexp-quote ";; [goggles]"))
                          +highlight)
    (error "missing section header")))

(+test "goggles block is commented out"
  (dolist (needle '("(use-package goggles"
                    ":hook ((prog-mode text-mode) . goggles-mode)"
                    "(setq-default goggles-pulse nil)"))
    (unless (string-match-p (concat "^;;[^\n]*"
                                    (regexp-quote needle))
                            +highlight)
      (error "commented-out %s missing" needle))))

(+test "so-long still lists goggles-mode"
  (unless (string-match-p "\\_<goggles-mode\\_>"
                          (+read "core/init-basic.el"))
    (error "so-long-minor-modes lost goggles-mode")))

(when +test-failures
  (princ (format "\n%d failure(s)\n" (length +test-failures)))
  (kill-emacs 1))
