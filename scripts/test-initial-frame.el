;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-initial-frame.el
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

(defconst +early-init
  (with-temp-buffer
    (insert-file-contents (expand-file-name "early-init.el" +repo))
    (buffer-string)))

(+test "no preset initial frame size"
  (when (string-match-p "initial-frame-alist" +early-init)
    (error "initial-frame-alist is still set"))
  (when (string-match-p "(push '(width " +early-init)
    (error "width is still pushed onto a frame alist"))
  (when (string-match-p "(push '(height " +early-init)
    (error "height is still pushed onto a frame alist")))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
