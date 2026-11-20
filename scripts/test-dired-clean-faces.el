;;; -*- lexical-binding: t -*-

;; dired 的两处额外着色都已关闭：dired-subtree 的深度背景与
;; dired-collapse 的 shadow overlay。两者都用硬编码颜色，不跟随主题。
;; 运行：cd ~/.config/emacs && emacs -Q --batch -l scripts/test-dired-clean-faces.el

(require 'cl-lib)

(defvar +test--failures 0)
(defvar +test--checks 0)

(defun +test--root ()
  "Return the repository root inferred from this file's location."
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (expand-file-name "scripts/test-dired-clean-faces.el"))))))

(defvar +test--root-dir (+test--root))
(defvar +test--config
  (or (getenv "DIRED_TEST_CONFIG")
      (expand-file-name "core/init-dired.el" +test--root-dir))
  "Config file under test; override with DIRED_TEST_CONFIG for a baseline run.")

(defun +test--expect (condition fmt &rest args)
  "Count a check; print PASS when CONDITION holds, else FAIL with FMT."
  (cl-incf +test--checks)
  (if condition
      (princ (format "PASS: %s\n" (apply #'format fmt args)))
    (cl-incf +test--failures)
    (princ (format "FAIL: %s\n" (apply #'format fmt args)))))

(defun +test--use-package (name)
  "Return the plist body of the `(use-package NAME ...)' form."
  (with-temp-buffer
    (insert-file-contents +test--config)
    (goto-char (point-min))
    (unless (re-search-forward
             (format "^[ \t]*(use-package %s\\_>" (regexp-quote name)) nil t)
      (error "use-package %s form not found in %s" name +test--config))
    (cddr (save-excursion
            (goto-char (match-beginning 0))
            (read (current-buffer))))))

(defun +test--apply-custom (plist)
  "Set the variables named in the :custom value of PLIST."
  (let ((custom (plist-get plist :custom))
        (i 0))
    (while (and custom (< i (length custom)))
      (set (nth i custom) (nth (1+ i) custom))
      (cl-incf i 2))))

(defun +test--load-path ()
  "Add the straight build directories these packages need."
  (dolist (pkg '("dired-hacks" "dash" "s" "f" "compat" "cond-let" "map"))
    (let ((dir (expand-file-name (concat "straight/build/" pkg) +test--root-dir)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

;; ---------------------------------------------------------------- driver

(princ (format "config: %s\n" +test--config))
(princ "command: cd ~/.config/emacs && emacs -Q --batch -l scripts/test-dired-clean-faces.el\n")

(defun +test--check-flag (package variable)
  "Assert PACKAGE's :custom sets VARIABLE to nil, in config and at runtime."
  (let* ((plist (condition-case err
                    (+test--use-package package)
                  (error
                   (princ (format "FAIL: %s\n" (error-message-string err)))
                   nil)))
         (custom (plist-get plist :custom)))
    (+test--expect (plist-member custom variable)
                   "%s :custom declares %s" package variable)
    (+test--expect (null (plist-get custom variable))
                   "%s :custom sets %s to nil (got %S)"
                   package variable (plist-get custom variable))
    (+test--apply-custom plist)
    (let ((value (and (boundp variable) (symbol-value variable))))
      (+test--expect (null value)
                     "runtime %s is nil (got %S)" variable value))))

(+test--load-path)
(condition-case err
    (progn (require 'dired-collapse) (require 'dired-subtree))
  (error (princ (format "FAIL: load failed: %s\n" (error-message-string err)))
         (kill-emacs 1)))

(+test--check-flag "dired-collapse" 'dired-collapse-fontify)
(+test--check-flag "dired-subtree" 'dired-subtree-use-backgrounds)

(if (zerop +test--failures)
    (progn
      (princ (format "RESULT: all %d checks passed\n" +test--checks))
      (kill-emacs 0))
  (princ (format "RESULT: %d of %d checks failed\n"
                 +test--failures +test--checks))
  (kill-emacs 1))

;;; test-dired-clean-faces.el ends here
