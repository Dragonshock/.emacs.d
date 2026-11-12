;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-elfeed-split.el
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

(add-to-list 'load-path (expand-file-name "straight/build/elfeed" +repo))
(require 'elfeed)

(defconst +elfeed-init
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-elfeed.el" +repo))
    (buffer-string)))

(defun +eval-defun (name)
  (with-temp-buffer
    (insert +elfeed-init)
    (goto-char (point-min))
    (unless (re-search-forward (format "^(defun %s " (regexp-quote name)) nil t)
      (error "missing %s" name))
    (goto-char (match-beginning 0))
    (eval (read (current-buffer)) t)))

(+test "entry window is reused on the right"
  (unless (string-match-p "elfeed-show-entry-switch #'\\+elfeed-display-entry" +elfeed-init)
    (error "switch function is not +elfeed-display-entry"))
  (when (string-match-p "elfeed-show-entry-delete #'delete-window" +elfeed-init)
    (error "still deleting the entry window"))
  (+eval-defun "+elfeed-show-window")
  (+eval-defun "+elfeed-display-entry")
  (let ((search (elfeed-search-buffer))
        (first (generate-new-buffer " *elfeed-entry-a*"))
        (second (generate-new-buffer " *elfeed-entry-b*")))
    (with-current-buffer search (elfeed-search-mode))
    (with-current-buffer first (elfeed-show-mode))
    (with-current-buffer second (elfeed-show-mode))
    (delete-other-windows)
    (switch-to-buffer search)
    (let ((show (+elfeed-display-entry first)))
      (unless (eq (selected-window) show)
        (error "focus left the first entry"))
      (unless (eq (window-in-direction 'left show) (get-buffer-window search))
        (error "entry is not to the right of search"))
      (let ((windows (length (window-list))))
        (+elfeed-display-entry second)
        (unless (= windows (length (window-list)))
          (error "next entry opened another window"))
        (unless (eq (window-buffer show) second)
          (error "entry window still shows %S" (window-buffer show)))
        (unless (eq (selected-window) show)
          (error "focus left the entry window"))
        (unless (eq (window-buffer (window-in-direction 'left show)) search)
          (error "search window was replaced"))))))

(when +test-failures
  (kill-emacs 1))
