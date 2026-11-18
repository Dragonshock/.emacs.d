;;; -*- lexical-binding: t -*-

;; Batch checks for the paren-matching configuration.
;;   emacs -Q --batch -l scripts/test-paren-upstream.el
;; `rainbow-delimiters' and `elec-pair' must stay upstream-identical;
;; `highlight-parentheses' is commented out on purpose, and
;; `show-paren-when-point-inside-paren' is deliberately nil.
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

(defun +upstream (relative)
  "Return upstream/master's version of RELATIVE."
  (let ((text (shell-command-to-string
               (format "git -C %s show upstream/master:%s"
                       (shell-quote-argument +repo) relative))))
    (when (string-empty-p text)
      (error "empty upstream text for %s" relative))
    text))

(defun +section (text header)
  "Return TEXT from HEADER to the next top-level `;; [' section."
  (let ((start (string-match (concat "^" (regexp-quote header)) text)))
    (unless start
      (error "missing section %s" header))
    (let ((next (string-match "^;; \\["
                              text (+ start (length header)))))
      (substring text start (or next (length text))))))

(defun +same-section (file header)
  (let ((local (+section (+read file) header))
        (up (+section (+upstream file) header)))
    (unless (string= local up)
      (error "%s: %s differs from upstream" file header))))

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

;; ------------------------------------------------- paren-matching blocks

(+test "show-paren-mode keeps the local quiet settings"
  (let ((block (+section (+read "core/init-highlight.el")
                         ";; [show-paren-mode]")))
    (dolist (needle '("show-paren-when-point-inside-paren nil"
                      "show-paren-when-point-in-periphery t"
                      "show-paren-context-when-offscreen t"
                      "blink-matching-paren-highlight-offscreen t"
                      "show-paren-delay 0.2"
                      "(:foreground \"SpringGreen3\""))
      (unless (string-match-p (regexp-quote needle) block)
        (error "missing %s" needle)))
    (when (string-match-p "show-paren-when-point-inside-paren t" block)
      (error "show-paren-when-point-inside-paren still t"))))

(+test "rainbow-delimiters block matches upstream"
  (+same-section "core/init-highlight.el" ";; [rainbow-delimiters]"))

(+test "highlight-parentheses block is commented out"
  (let ((text (+read "core/init-highlight.el")))
    (when (string-match-p "^[ \t]*(use-package highlight-parentheses" text)
      (error "use-package highlight-parentheses is still active"))
    (unless (string-match-p (concat "^" (regexp-quote ";; [highlight-parentheses]"))
                            text)
      (error "section header missing"))
    (unless (string-match-p
             "^;;[ \t]*(use-package highlight-parentheses" text)
      (error "commented-out use-package missing"))
    (unless (string-match-p
             "^;;[^\n]*highlight-parentheses-colors" text)
      (error "commented-out config missing"))))

(+test "elec-pair block matches upstream"
  (+same-section "core/init-edit.el" ";; [elec-pair]"))

(+test "show-paren-mode is never turned off"
  (let ((text (+read "core/init-highlight.el")))
    (when (string-match-p "(show-paren-mode -1)" text)
      (error "found (show-paren-mode -1)"))
    (when (string-match-p "\\_<+paren-matching-enabled\\_>" text)
      (error "leftover disable switch"))))

(+test "shell pairing setup pairs and widens the field search"
  (require 'elec-pair)
  (+load-defun (+read "core/init-edit.el") "+electric-pair-shell-setup")
  (with-temp-buffer
    (setq-local electric-pair-field-search-size 1)
    (electric-pair-mode -1)
    (+electric-pair-shell-setup)
    (unless electric-pair-mode
      (error "electric-pair-mode not enabled"))
    (unless (eql electric-pair-field-search-size 4096)
      (error "field search size is %S" electric-pair-field-search-size))))

;; ---------------------------------------------------------------- result

(when +test-failures
  (princ (format "\n%d failure(s)\n" (length +test-failures)))
  (kill-emacs 1))
