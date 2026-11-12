;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-org-straight.el
;; Does not load init.el, so it does not touch the Rime database.
;; Reads only the :straight keyword of (use-package org) in core/init-org.el.

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

(defun +init-org-use-package (name)
  "Return the body of (use-package NAME) in core/init-org.el."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-org.el" +repo))
    (goto-char (point-min))
    (let (found)
      (while (and (not found) (not (eobp)))
        (let ((form (condition-case nil
                        (read (current-buffer))
                      (end-of-file nil))))
          (when (and (consp form)
                     (eq (car form) 'use-package)
                     (eq (cadr form) name))
            (setq found (cddr form)))))
      (unless found
        (error "No (use-package %s) form" name))
      found)))

(+test "org is installed by straight"
  (let ((straight (plist-get (+init-org-use-package 'org) :straight)))
    (unless (eq straight t)
      (error "Expected :straight t, got %S" straight))))

(+test "org-persist and org-element stay outside straight"
  (dolist (name '(org-persist org-element))
    (let ((straight (plist-get (+init-org-use-package name) :straight)))
      (unless (eq straight nil)
        (error "%s :straight is %S, expected nil" name straight)))))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
