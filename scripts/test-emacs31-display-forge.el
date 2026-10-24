;;; -*- lexical-binding: t -*-

;; Batch checks for the Emacs 31 display and Forge updates.  Run from
;; the repo root:
;;   emacs -Q --batch -l scripts/test-emacs31-display-forge.el
;; Nothing here loads the running config, so it does not touch Rime.

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

(defun +code (relative)
  "Return RELATIVE's Lisp with comment lines removed."
  (mapconcat (lambda (line)
               (if (string-match-p "\\`[[:space:]]*;" line) "" line))
             (split-string (+read relative) "\n")
             "\n"))

(+test "display-comint-buffer-action is gone in this Emacs"
  (when (boundp 'display-comint-buffer-action)
    (error "still bound")))

(defun +window-top (window)
  "Return WINDOW's top edge in lines."
  (nth 1 (window-edges window)))

(defun +bottom-window ()
  "Return the lowest live window on the selected frame."
  (car (sort (window-list nil 'nomini)
             (lambda (a b) (> (+window-top a) (+window-top b))))))

(+test "category comint alist beats eshell's same-window action"
  (let* ((display-buffer-alist
          '(((category . comint)
             (display-buffer-at-bottom)
             (inhibit-same-window . nil))))
         (top (selected-window))
         (below (split-window-below))
         (buf (get-buffer-create " *test-comint-bottom*")))
    (unwind-protect
        (let ((win (display-buffer
                    buf
                    '(display-buffer-same-window
                      (inhibit-same-window . nil)
                      (category . comint)))))
          (unless (eq win (+bottom-window))
            (error "comint buffer landed in %S, bottom is %S" win (+bottom-window)))
          (when (eq win top)
            (error "stayed in the selected window")))
      (when (window-live-p below) (delete-window below))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(+test "category rule leaves a non-comint same-window display alone"
  (let* ((display-buffer-alist
          '(((category . comint)
             (display-buffer-at-bottom)
             (inhibit-same-window . nil))))
         (top (selected-window))
         (below (split-window-below))
         (buf (get-buffer-create " *test-not-comint*")))
    (unwind-protect
        (let ((win (display-buffer buf '(display-buffer-same-window
                                         (inhibit-same-window . nil)))))
          (unless (eq win top)
            (error "non-comint buffer left the selected window: %S" win)))
      (when (window-live-p below) (delete-window below))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(+test "an earlier alist rule still wins over the comint category"
  (let* ((claimed nil)
         (display-buffer-alist
          `((,(lambda (buf-or-name _action)
                (setq claimed buf-or-name)
                (let ((name (if (stringp buf-or-name)
                                buf-or-name
                              (buffer-name buf-or-name))))
                  (string-match-p "\\`Eshell-popup:" name)))
             display-buffer-same-window)
            ((category . comint)
             (display-buffer-at-bottom)
             (inhibit-same-window . nil))))
         (top (selected-window))
         (below (split-window-below))
         (buf (get-buffer-create "Eshell-popup: test")))
    (unwind-protect
        (let ((win (display-buffer
                    buf
                    '(display-buffer-same-window
                      (inhibit-same-window . nil)
                      (category . comint)))))
          (unless (eq win top)
            (error "earlier rule lost to the category rule: %S" win))
          (unless (or (eq claimed buf)
                      (equal claimed (buffer-name buf)))
            (error "earlier predicate did not see the buffer: %S" claimed)))
      (when (window-live-p below) (delete-window below))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(+test "installed forge does not define forge-topic-list-columns"
  (let ((hits nil))
    (dolist (file (directory-files-recursively
                   (expand-file-name "straight/repos/forge" +repo)
                   "\\.el\\'"))
      (with-temp-buffer
        (insert-file-contents file)
        (when (search-forward "forge-topic-list-columns" nil t)
          (push (file-name-nondirectory file) hits))))
    (when hits
      (error "still defined in %S" hits))))

(+test "config no longer uses the removed comint action"
  (let ((text (+code "core/init-shell.el")))
    (when (string-match-p "display-comint-buffer-action" text)
      (error "removed variable still referenced"))
    (unless (string-match-p "(category \. comint)" text)
      (error "comint category rule missing"))
    (unless (string-match-p "display-buffer-at-bottom" text)
      (error "bottom action missing"))
    (unless (string-match-p "(append display-buffer-alist" text)
      (error "rule is not appended after earlier alist entries"))))

(+test "config no longer sets forge-topic-list-columns"
  (dolist (file '("core/init-vcs.el" "core/init-shell.el"))
    (when (string-match-p "forge-topic-list-columns" (+code file))
      (error "%s still sets it" file)))
  (unless (string-match-p "forge-topic-label" (+code "core/init-vcs.el"))
    (error "forge topic face customization was removed")))

(+test "edited forms are balanced"
  (dolist (file '("core/init-shell.el" "core/init-vcs.el"))
    (with-temp-buffer
      (insert-file-contents (expand-file-name file +repo))
      (emacs-lisp-mode)
      (goto-char (point-min))
      (condition-case err
          (while (not (eobp))
            (forward-sexp 1))
        (scan-error (error "%s: %S" file err))))))

(when +test-failures
  (kill-emacs 1))
