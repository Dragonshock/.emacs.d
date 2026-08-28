;;; -*- lexical-binding: t -*-

;; [org-fragtog] Preview and edit latex in md/org elegantly
;; (use-package org-fragtog
;;   :straight t
;;   :hook ((org-mode . org-fragtog-mode)))

;; [org]
(defconst +org-directory
  (expand-file-name "~/Documents/90-agenda/")
  "Root of personal Org files (agenda / capture / drill).")

(defconst +org-agenda-directory
  (expand-file-name "agenda/" +org-directory)
  "Directory scanned by `org-agenda' and used by `org-capture'.")

;; Dynamically rebound by `+org-save-buffer-after-capture-refile-a'.
(defvar org-after-refile-insert-hook)

;; [org-persist]
(use-package org-persist
  :straight nil
  :init
  (setq org-persist-directory (no-littering-expand-var-file-name "org/persist/")))

(use-package org
  :straight (:type built-in)
  :init
  ;; Load optional Org modules only when explicitly enabled.
  (setq org-modules nil
        org-hide-emphasis-markers t)
  ;; Upstream: C-c a / C-c n c.  Leave C-c c for citre (init-prog.el).
  :bind (("C-c a" . org-agenda)
         ("C-c n c" . org-capture))
  :custom-face (org-quote ((t (:inherit org-block-begin-line))))
  :hook ((org-mode . (lambda () (setq-local dabbrev-abbrev-skip-leading-regexp "[=*]")))  ;; Skipping leading char, so corfu can complete with dabbrev for formatted text
         (org-mode . (lambda ()
                       (push '("\\operatorname{\\mathrm{" . (?  (Bc . Bl) ?{ (Bc . Br) ?{)) prettify-symbols-alist)
                       (push '("\\mathcal{" . (?  (Bc . Bl) ?{ (Bc . Br) ?𝒞)) prettify-symbols-alist)
                       (push '("\\mathbb{" . (?  (Bc . Bl) ?{ (Bc . Br) ?𝔹)) prettify-symbols-alist)
                       (push '("\\\\{" . ?{) prettify-symbols-alist)
                       (push '("\\\\}" . ?}) prettify-symbols-alist)
                       (push '("\\vec{" . (?  (Bc . Bl) ?{ (Bc . Br) ?⃗)) prettify-symbols-alist)
                       (push '("\\ " . ?‿) prettify-symbols-alist)
                       (prettify-symbols-mode))))
  :config
  (setq
   ;; subscription: Use {} for sub- or super- scripts
   org-use-sub-superscripts '{}
   org-export-with-sub-superscripts '{}

   ;; prettify
   org-startup-indented t
   ;; Respect #+startup visibility, archived trees, drawers, and hidden blocks.
   org-startup-folded nil
   org-pretty-entities t
   org-ellipsis "…"
   ;; Highlight quote and verse blocks
   org-fontify-quote-and-verse-blocks t
   ;; Highlight the whole line for headings
   org-fontify-whole-heading-line t
   org-image-actual-width nil
   org-priority-faces '((?A . error)
                        (?B . warning)
                        (?C . shadow))

   ;; Edit settings
   org-auto-align-tags nil
   org-tags-column 0
   org-M-RET-may-split-line nil
   org-insert-heading-respect-content t

   ;; better keybindings
   org-special-ctrl-a/e t
   org-special-ctrl-k t
   org-special-ctrl-o t
   org-support-shift-select t
   org-ctrl-k-protect-subtree 'error
   org-fold-catch-invisible-edits 'show-and-error

   org-imenu-depth 4

   org-directory +org-directory
   org-agenda-files (list +org-agenda-directory)
   org-default-notes-file (expand-file-name "agenda.org" +org-agenda-directory)
   org-capture-templates
   '(("t" "Todo" entry
      (file+headline org-default-notes-file "Inbox")
      "* TODO %?\n%u\n"))

   org-log-done 'time
   org-log-into-drawer t
   org-log-reschedule 'time
   org-log-redeadline 'time

   org-agenda-span 7
   org-agenda-start-on-weekday 1
   org-agenda-window-setup 'current-window
   org-agenda-restore-windows-after-quit t
   org-agenda-tags-column 0

   ;; Keep generated LaTeX previews out of note directories.
   org-preview-latex-image-directory (no-littering-expand-var-file-name "org/latex/")
   ;; Recognize a), A), a., and A. as list markers.
   org-list-allow-alphabetical t

   org-agenda-skip-unavailable-files t
   org-agenda-skip-scheduled-if-done t
   org-agenda-skip-deadline-if-done t
   org-agenda-deadline-faces '((1.001 . error)
                               (1.0 . org-warning)
                               (0.5 . org-upcoming-deadline)
                               (0.0 . org-upcoming-distant-deadline))

   ;; Source blocks
   org-src-preserve-indentation t
   org-src-window-setup 'other-window

   ;; Store ID-based attachments centrally and inherit them in subtrees.
   org-attach-id-dir (expand-file-name ".attach/" org-directory)
   org-attach-use-inheritance t
   org-archive-subtree-save-file-p t
   org-num-face '(:inherit org-special-keyword :underline nil :weight bold)
   org-num-skip-tags '("noexport" "nonum"))

  (make-directory +org-agenda-directory t)

  ;; Better Org Latex Preview
  (setq org-preview-latex-default-process 'dvisvgm
        org-startup-with-latex-preview nil
        org-highlight-latex-and-related '(latex))
  ;; Copy the defcustom plist so we do not mutate the shared standard value;
  ;; dvisvgm's :image-size-adjust still multiplies with :scale.
  (setq org-format-latex-options
        (plist-put (copy-tree org-format-latex-options) :scale 1.7))

  ;; CJK-friendly emphasis boundaries for font-lock only.
  ;; `org-emphasis-regexp-components' does not change the Org parser/export
  ;; markup rules, so skip org-element-update-syntax / org-element--set-regexps.
  ;; Keep ASCII letters out of the border classes so paths like
  ;; `=/usr/bin/foo=' are not fontified as verbatim (upstream 8f668f5).
  (setq org-emphasis-regexp-components '("-[:space:]('\"{[:nonascii:]"
                                         "-[:space:].,:!?;'\")}\\[[:nonascii:]"
                                         "[:space:]"
                                         "."
                                         1))
  (org-set-emph-re 'org-emphasis-regexp-components org-emphasis-regexp-components)

  ;; Common web and local-note link abbreviations (upstream f2349e8).
  (dolist (abbrev '(("github" . "https://github.com/%s")
                    ("youtube" . "https://youtube.com/watch?v=%s")
                    ("google" . "https://google.com/search?q=%s")
                    ("gmap" . "https://maps.google.com/maps?q=%s")
                    ("wiki" . "https://en.wikipedia.org/wiki/%s")
                    ("wolfram" . "https://wolframalpha.com/input/?i=%s")
                    ("org" . (lambda (path)
                               (abbreviate-file-name
                                (expand-file-name path org-directory))))))
    (add-to-list 'org-link-abbrev-alist abbrev))

  ;; Open file links in place, directories in Dired, and flag broken links.
  (setf (alist-get 'file org-link-frame-setup) #'find-file)
  (add-to-list 'org-file-apps '(directory . emacs))
  (add-to-list 'org-file-apps '(remote . emacs))
  (defun +org-file-link-face (path)
    "Use a warning face for a missing local Org file link at PATH."
    (if (or (file-remote-p path)
            (file-exists-p (expand-file-name (org-link-unescape path))))
        'org-link
      '(warning org-link)))
  (org-link-set-parameters "file" :face #'+org-file-link-face)

  (add-to-list 'org-src-lang-modes '("md" . markdown-ts-mode))
  (define-key org-src-mode-map (kbd "C-c C-c") #'org-edit-src-exit)

  ;; Block delimiter faces inherit from `org-meta-line'.
  (dolist (face '(org-meta-line org-block-begin-line org-block-end-line))
    (set-face-attribute face nil :height 0.85))

  ;; Cycle the visible parent heading when point is in or just past folded text.
  (add-hook! org-cycle-tab-first-hook
    (defun +org-cycle-visible-heading ()
      "Cycle the visible parent heading at either edge of a folded subtree."
      (when-let* ((folded-region (or (org-fold-get-region-at-point 'headline)
                                     (and (> (point) (point-min))
                                          (org-fold-get-region-at-point
                                           'headline (1- (point)))))))
        (goto-char (car folded-region))
        (org-back-to-heading t)
        (org-cycle)
        t)))

  (add-hook! org-babel-after-execute-hook
    (defun +org-redisplay-inline-images-in-babel-result-h ()
      "Refresh inline images produced by the Babel block at point.
After Babel inserts its result, find that result's bounds and refresh link
previews only within that region.  Skip exports and temporary buffers to avoid
unnecessary display work during non-interactive operations."
      (unless (or (bound-and-true-p org-export-current-backend)
                  (string-prefix-p " *temp" (buffer-name)))
        (save-excursion
          (when-let* ((beg (org-babel-where-is-src-block-result))
                      (end (progn
                             (goto-char beg)
                             (forward-line)
                             (org-babel-result-end))))
            (org-link-preview-region nil t (min beg end) (max beg end)))))))

  (defadvice! +org-save-buffer-after-capture-refile-a (fn &rest args)
    :around #'org-refile
    "Save the refile target after moving an entry from `org-capture'.
Temporarily prepend `save-buffer' to `org-after-refile-insert-hook' only while
`org-capture-is-refiling' is non-nil, leaving ordinary refiles unchanged."
    (let ((org-after-refile-insert-hook
           (if (bound-and-true-p org-capture-is-refiling)
               (cons #'save-buffer org-after-refile-insert-hook)
             org-after-refile-insert-hook)))
      (apply fn args)))
  )


;; [ob-mermaid] Generate Mermaid diagrams through Org Babel
(use-package ob-mermaid
  :straight t
  :after org
  :init
  (setf (alist-get 'mermaid org-babel-load-languages) t)
  :config
  (setq ob-mermaid-default-config-file
        (no-littering-expand-etc-file-name "mermaid/config.json")))


;; [org-entities]
(use-package org-entities
  :config
  (setq org-entities-user
        '(("vdash" "\\vdash" t "⊢" "⊢" "⊢" "⊢")
          ("vDash" "\\vDash" t "⊨" "⊨" "⊨" "⊨")
          ("Vdash" "\\Vdash" t "⊩" "⊩" "⊩" "⊩")
          ("Vvdash" "\\Vvdash" t "⊪" "⊪" "⊪" "⊪")
          ("nvdash" "\\nvdash" t "⊬" "⊬" "⊬" "⊬")
          ("nvDash" "\\nvDash" t "⊭" "⊭" "⊭" "⊭")
          ("nVdash" "\\nVdash" t "⊮" "⊮" "⊮" "⊮")
          ("nVDash" "\\nVDash" t "⊯" "⊯" "⊯" "⊯")
          ("subseteq" "\\subseteq" t "⊆" "⊆" "⊆" "⊆")
          ("supseteq" "\\supseteq" t "⊇" "⊇" "⊇" "⊇")
          ("subsetneq" "\\subsetneq" t "⊊" "⊊" "⊊" "⊊")
          ("supsetneq" "\\supsetneq" t "⊋" "⊋" "⊋" "⊋")
          ("nsubseteq" "\\nsubseteq" t "⊈" "⊈" "⊈" "⊈")
          ("nsupseteq" "\\nsupseteq" t "⊉" "⊉" "⊉" "⊉")
          ("nsubseteqq" "\\nsubseteqq" t "⊈" "⊈" "⊈" "⊈")
          ("nsupseteqq" "\\nsupseteqq" t "⊉" "⊉" "⊉" "⊉")
          ("subsetneqq" "\\subsetneqq" t "⊊" "⊊" "⊊" "⊊")
          ("supsetneqq" "\\supsetneqq" t "⊋" "⊋" "⊋" "⊋")
          ("nsubset" "\\nsubset" t "⊄" "⊄" "⊄" "⊄")
          ("nsupset" "\\nsupset" t "⊅" "⊅" "⊅" "⊅"))))


;; [org-appear] Make invisible parts of Org elements appear visible.
;; `always': init-modal/meow is off, so `manual' + meow insert hooks
;; would never fire and markers would stay hidden.
(use-package org-appear
  :straight t
  :hook ((org-mode . org-appear-mode))
  :config
  (setq
   org-appear-autosubmarkers t
   org-appear-autoentities t
   org-appear-autokeywords t
   org-appear-inside-latex t

   org-appear-delay 0.1

   org-appear-trigger 'always))


(use-package org-modern
  :straight t
  :after org
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda))
  :custom
  ;; Tables: leave pixel alignment to valign (init-writing.el).
  ;; org-modern table display props conflict with valign overlays.
  (org-modern-table nil))

;; Align upstream 3608874: org-modern-indent off (indent/valign clash).
;; (use-package org-modern-indent
;;   :straight (org-modern-indent :type git :host github :repo "jdtsmith/org-modern-indent")
;;   :config
;;   (add-hook! org-mode-hook :depth 90 #'org-modern-indent-mode))


;; [ox]
(use-package ox
  :config
  (setq org-export-with-smart-quotes t
        org-html-validation-link nil
        org-latex-prefer-user-labels t
        org-export-with-latex t))
