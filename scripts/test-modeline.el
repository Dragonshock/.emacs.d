;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-modeline.el
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

(defconst +modeline
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-modeline.el" +repo))
    (buffer-string)))

(+test "native mode line is not replaced"
  (when (string-match-p "doom-modeline" +modeline)
    (error "doom-modeline is still configured"))
  (when (string-match-p "\\+mode-line-normal" +modeline)
    (error "custom mode line is still installed"))
  (when (string-match-p "(setq-default mode-line-format" +modeline)
    (error "mode-line-format is overridden")))

(defun +load-mode-line-box ()
  (with-temp-buffer
    (insert +modeline)
    (goto-char (point-min))
    (re-search-forward "(defun \\+mode-line-box-match-background ")
    (goto-char (match-beginning 0))
    (eval (read (current-buffer)) t)))

(+load-mode-line-box)

(+test "mode-line box uses the face background"
  (require 'cl-lib)
  (let ((faces nil))
    (cl-letf (((symbol-function 'face-background)
               (lambda (face &rest _)
                 (if (eq face 'mode-line) "#111111" "#222222")))
              ((symbol-function 'set-face-attribute)
               (lambda (face _ &rest attrs)
                 (push (cons face attrs) faces))))
      (+mode-line-box-match-background))
    (setq faces (nreverse faces))
    (unless (equal faces
                   '((mode-line :overline nil :box (:line-width 1 :color "#111111"))
                     (mode-line-inactive :overline nil :box (:line-width 1 :color "#222222"))))
      (error "faces %S" faces))))

(defun +load-tab-underline ()
  (with-temp-buffer
    (insert +modeline)
    (goto-char (point-min))
    (re-search-forward "(defun \\+tab-bar-selected-underline-off ")
    (goto-char (match-beginning 0))
    (eval (read (current-buffer)) t)))

(+load-tab-underline)

(+test "selected tab underline is removed"
  (require 'cl-lib)
  (let ((faces nil))
    (cl-letf (((symbol-function 'set-face-attribute)
               (lambda (face _ &rest attrs)
                 (push (cons face attrs) faces))))
      (+tab-bar-selected-underline-off))
    (unless (equal (nreverse faces)
                   '((tab-bar-tab :underline nil)))
      (error "faces %S" faces))
    (unless (string-match-p "left unchanged" +modeline)
      (error "tab-line was not explicitly left alone"))
    (when (string-match-p "tab-line-tab-current" +modeline)
      (error "tab-line face was changed"))))

(+test "tab bar indicators stay outside the mode line"
  (unless (string-match-p "\\+tab-bar-telega-indicator-update" +modeline)
    (error "telega tab indicator removed"))
  (unless (string-match-p "\\+mode-line-meta-face" +modeline)
    (error "popper face removed")))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
