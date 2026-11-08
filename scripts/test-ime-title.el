;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-ime-title.el
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

(defconst +ime
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-ime.el" +repo))
    (buffer-string)))

(defun +load-hide-title ()
  (with-temp-buffer
    (insert +ime)
    (goto-char (point-min))
    (re-search-forward "(defun \\+ime-hide-input-method-title ")
    (goto-char (match-beginning 0))
    (eval (read (current-buffer)) t)))

(+load-hide-title)

(+test "rime title is cleared when the input method activates"
  (unless (string-match-p "input-method-activate-hook #'\\+ime-hide-input-method-title" +ime)
    (error "hook is not installed"))
  (setq current-input-method-title "ㄓ")
  (+ime-hide-input-method-title)
  (unless (equal current-input-method-title "")
    (error "title %S" current-input-method-title)))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
