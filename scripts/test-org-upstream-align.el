;;; -*- lexical-binding: t -*-

;; Batch checks for the Org alignment.  Run from the repo root:
;;   emacs -Q --batch -l scripts/test-org-upstream-align.el
;; Uses built-in Org only.  It does not load the running config or Rime.

(defvar +test-failures nil)

(defmacro +test (name &rest body)
  `(let ((err (condition-case e
                  (progn ,@body nil)
                (error e))))
     (if err
         (progn (push ,name +test-failures)
                (princ (format "FAIL %s: %S\n" ,name err)))
       (princ (format "PASS %s\n" ,name)))))

(require 'org)

(defun +org-fontify-special-blocks (limit)
  "Add `org-block' to special block contents found before LIMIT."
  (let ((case-fold-search t))
    (while (re-search-forward "^[ \t]*#\\+begin_\\S-+" limit t)
      (let ((block (save-excursion
                     (beginning-of-line)
                     (org-element-at-point))))
        (when (eq (org-element-type block) 'special-block)
          (when-let* ((begin (org-element-property :contents-begin block))
                      (end (org-element-property :contents-end block)))
            (add-face-text-property begin end 'org-block t))))))
  nil)

(defun +face-at (buffer pos)
  (with-current-buffer buffer
    (get-text-property pos 'face)))

(+test "special block contents receive org-block"
  (with-temp-buffer
    (org-mode)
    (insert "#+begin_question\nWhat is it?\n#+end_question\n")
    (goto-char (point-min))
    (+org-fontify-special-blocks (point-max))
    (let ((pos (search-forward "What")))
      (unless (eq (+face-at (current-buffer) (1- pos)) 'org-block)
        (error "face is %S" (+face-at (current-buffer) (1- pos)))))))

(+test "source blocks are not treated as special blocks"
  (with-temp-buffer
    (org-mode)
    (insert "#+begin_src emacs-lisp\n(+ 1 1)\n#+end_src\n")
    (goto-char (point-min))
    (+org-fontify-special-blocks (point-max))
    (let ((pos (search-forward "+ 1")))
      (when (eq (+face-at (current-buffer) (1- pos)) 'org-block)
        (error "src contents were painted as a special block")))))

(+test "transparent background keeps the existing preview scale"
  (let ((org-format-latex-options (copy-tree org-format-latex-options)))
    (plist-put org-format-latex-options :scale 1.2)
    (plist-put org-format-latex-options :background "Transparent")
    (unless (equal (plist-get org-format-latex-options :scale) 1.2)
      (error "scale changed to %S" (plist-get org-format-latex-options :scale)))
    (unless (equal (plist-get org-format-latex-options :background) "Transparent")
      (error "background is %S" (plist-get org-format-latex-options :background)))))

(defconst +repo (expand-file-name ".." (file-name-directory load-file-name)))

(defun +read (relative)
  (with-temp-buffer
    (insert-file-contents (expand-file-name relative +repo))
    (buffer-string)))

(+test "config fontifies special blocks and keeps preview scale"
  (let ((text (+read "core/init-org.el")))
    (unless (string-match-p "(defun \\+org-fontify-special-blocks" text)
      (error "fontify function missing"))
    (unless (string-match-p "font-lock-add-keywords 'org-mode '((\\+org-fontify-special-blocks))" text)
      (error "font-lock keyword missing"))
    (unless (string-match-p "plist-put org-format-latex-options :scale 1\\.2" text)
      (error "scale is not 1.2"))
    (unless (string-match-p ":background \"Transparent\"" text)
      (error "transparent background missing"))
    (unless (string-match-p "(use-package org-fragtog" text)
      (error "org-fragtog missing"))
    (unless (string-match-p "org-mode \\. org-fragtog-mode" text)
      (error "fragtog hook missing"))
    (unless (string-match-p "org-appear-inside-latex t" text)
      (error "org-appear latex setting changed"))
    (unless (string-match-p "(use-package org-typst-preview" text)
      (error "org-typst-preview was removed"))
    (when (string-match-p "org-directory .*Nutstore" text)
      (error "org directory was pointed at Nutstore"))))

(+test "init-org forms are balanced"
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-org.el" +repo))
    (emacs-lisp-mode)
    (goto-char (point-min))
    (condition-case err
        (while (not (eobp))
          (forward-sexp 1))
      (scan-error (error "%S" err)))))

(when +test-failures
  (kill-emacs 1))
