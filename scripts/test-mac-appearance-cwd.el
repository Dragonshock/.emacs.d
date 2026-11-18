;;; -*- lexical-binding: t -*-

;; Batch checks for the macOS appearance cwd hardening.
;;   emacs -Q --batch -l scripts/test-mac-appearance-cwd.el
;; `+mac-read-system-appearance' must survive `default-directory'
;; pointing at a deleted directory, so the 2-second sync timer in
;; core/init-mac.el stops raising file-missing ("Setting current
;; directory") over and over.  Stubs `+system-appearance' and
;; `+system-appearance-changed', extracts the two real defuns from
;; core/init-mac.el, and calls them with a deleted cwd.
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

(defun +load-defun (text name)
  "Eval the top-level defun NAME from TEXT and return it."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (unless (re-search-forward
             (format "^[ \t]*(defun %s " (regexp-quote name)) nil t)
      (error "missing defun %s" name))
    (goto-char (match-beginning 0))
    (eval (read (current-buffer)) t)))

;; ---------------------------------------------------- stubs and real code

(defvar +system-appearance nil
  "Test stub for the real defvar in core/init-ui.el.")

(defvar +test-appearance-changed-called nil)

(defun +system-appearance-changed (appearance)
  "Test stub: record the new appearance and set an observable flag."
  (setq +system-appearance appearance
        +test-appearance-changed-called t))

(defconst +mac-text (+read "core/init-mac.el"))
(+load-defun +mac-text "+mac-read-system-appearance")
(+load-defun +mac-text "+mac-sync-system-appearance")

;; ------------------------------------------------------------- use cases

;; Use case 1 (the regression this fixes): a deleted default-directory.

(+test "+mac-read-system-appearance survives a deleted default-directory"
  (let ((old default-directory))
    (unwind-protect
        (let ((dir (make-temp-file "+mac-appearance-cwd-" t)))
          (delete-directory dir t)
          (setq default-directory (file-name-as-directory dir))
          (let ((appearance (+mac-read-system-appearance)))
            (unless (memq appearance '(dark light))
              (error "appearance was %S" appearance))))
      (setq default-directory old))))

(+test "+mac-sync-system-appearance survives a deleted default-directory"
  (let ((old default-directory))
    (unwind-protect
        (let ((dir (make-temp-file "+mac-appearance-cwd-" t)))
          (delete-directory dir t)
          (setq default-directory (file-name-as-directory dir))
          (setq +test-appearance-changed-called nil)
          (+mac-sync-system-appearance))
      (setq default-directory old))))

;; Use case 2 (control): an existing default-directory still works.

(+test "both functions work with an existing default-directory"
  (setq default-directory (expand-file-name "~/"))
  (let ((appearance (+mac-read-system-appearance)))
    (unless (memq appearance '(dark light))
      (error "appearance was %S" appearance)))
  (setq +test-appearance-changed-called nil)
  (+mac-sync-system-appearance)
  (unless (memq +system-appearance '(dark light))
    (error "+system-appearance was %S" +system-appearance)))

;; Use case 3 (text needles, anti-regression): the hardening must stay
;; in core/init-mac.el.

(+test "init-mac.el keeps the file-directory-p fallback"
  (let ((text (+read "core/init-mac.el")))
    (unless (string-match-p "(let ((default-directory" text)
      (error "missing default-directory let binding"))
    (unless (string-match-p "(file-directory-p default-directory)" text)
      (error "missing file-directory-p fallback"))
    (unless (string-match-p "\"/\"" text)
      (error "missing root-directory fallback"))))

;; ---------------------------------------------------------------- result

(when +test-failures
  (princ (format "\n%d failure(s)\n" (length +test-failures)))
  (kill-emacs 1))
