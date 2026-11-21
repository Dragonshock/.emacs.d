;;; -*- lexical-binding: t -*-

;; [kill-ring]
(setq
 ;; Do not add the duplicates that the same as the last one to kill-ring
 kill-do-not-save-duplicates t
 ;; Save clipboard contents into kill-ring before replace them
 save-interprogram-paste-before-kill t)

(kill-ring-deindent-mode)


;; Make script file executable with `chmod +x' after save
(add-hook! after-save-hook #'executable-make-buffer-file-executable-if-script-p)


;; [autorevert]
(use-package autorevert
  :hook (find-file . +auto-revert-mode)
  :config
  (setq auto-revert-verbose t
        auto-revert-use-notify nil
        auto-revert-stop-on-user-input nil
        ;; Only prompts for confirmation when buffer is unsaved.
        revert-without-query (list "."))

  (defun +auto-revert-buffer-h (&rest _)
    "Auto revert current buffer when it is stale."
    (unless (or (active-minibuffer-window)
                (and (not auto-revert-remote-files)
                     buffer-file-name
                     (file-remote-p buffer-file-name)))
      (let ((auto-revert-mode t))
        (auto-revert-handler))))

  (defun +auto-revert-window-buffer-h (window &rest _)
    "Auto revert WINDOW's buffer when it is stale."
    (when (window-live-p window)
      (with-current-buffer (window-buffer window)
        (+auto-revert-buffer-h))))

  (defun +auto-revert-selected-window-h (&optional frame)
    "Auto revert the selected window's buffer in FRAME."
    (+auto-revert-window-buffer-h
     (frame-selected-window (or frame (selected-frame)))))

  (defun +auto-revert-visible-buffers-h (&rest _)
    "Auto revert visible stale buffers."
    (dolist (buffer (delete-dups (mapcar #'window-buffer (window-list-1 nil 'no-minibuf t))))
      (with-current-buffer buffer
        (+auto-revert-buffer-h))))

  (define-minor-mode +auto-revert-mode
    "A lazy alternative to `global-auto-revert-mode'."
    :global t
    (when global-auto-revert-mode
      (setq +auto-revert-mode nil))
    (let ((fn (if +auto-revert-mode #'add-hook #'remove-hook)))
      (funcall fn 'window-buffer-change-functions #'+auto-revert-window-buffer-h)
      (funcall fn 'window-selection-change-functions #'+auto-revert-selected-window-h)
      (funcall fn 'focus-in-hook #'+auto-revert-visible-buffers-h)
      (funcall fn 'after-save-hook #'+auto-revert-visible-buffers-h)
      (funcall fn 'server-switch-hook #'+auto-revert-buffer-h))))


;; [ws-butler] Remove trailing whitespace with lines touched
(use-package ws-butler
  :straight t
  :hook ((prog-mode markdown-ts-mode) . ws-butler-mode))


;; [editorconfig] Respect project-local formatting rules
(use-package editorconfig
  :hook (after-init . editorconfig-mode))


;; [apheleia] Format buffers asynchronously without moving point
(use-package apheleia
  :straight t
  :commands (apheleia-format-buffer)
  :bind (("C-c r f" . apheleia-format-buffer))
  :hook (after-init . apheleia-global-mode)
  :config
  (setq apheleia-hide-log-buffers t))


;; [ispell] Spell-checker backend
(use-package ispell
  :hook ((org-mode . +ispell-org-skip-regions-h)
         ((markdown-mode markdown-ts-mode) . +ispell-markdown-skip-regions-h))
  :config
  (defun +ispell-org-skip-regions-h ()
    "Exclude Org blocks and inline markup from spell checking."
    (make-local-variable 'ispell-skip-region-alist)
    (dolist (pair '((org-property-drawer-re)
                    ("~" "~") ("=" "=")
                    ("^#\\+BEGIN_SRC" "^#\\+END_SRC")
                    ("\\\\(" "\\\\)") ("\\[" "\\]")
                    ("^\\\\begin{[^}]+}" "^\\\\end{[^}]+}")))
      (add-to-list 'ispell-skip-region-alist pair)))

  (defun +ispell-markdown-skip-regions-h ()
    "Exclude Markdown code and inline markup from spell checking."
    (make-local-variable 'ispell-skip-region-alist)
    (dolist (pair '(("`" "`")
                    ("^```" "^```")
                    ("{{" "}}")
                    ("\\\\(" "\\\\)") ("\\[" "\\]")
                    ("^\\\\begin{[^}]+}" "^\\\\end{[^}]+}")))
      (add-to-list 'ispell-skip-region-alist pair)))

  (setq ispell-program-name "aspell"
        ispell-extra-args nil
        ispell-dictionary "en_US"
        ispell-personal-dictionary (no-littering-expand-var-file-name "ispell/.pws")))


;; [flyspell] Spell-checking overlays for writing modes
(use-package flyspell
  :hook ((org-mode markdown-mode markdown-ts-mode typst-ts-mode
                   tex-mode TeX-mode) . flyspell-mode)
  :bind (:map flyspell-mode-map
              ("C-c s ]" . flyspell-goto-next-error)
              ("C-c s [" . +flyspell-goto-previous-error)
              ("C-c s s" . flyspell-auto-correct-word)
              ("C-;" . nil)
              ("C-," . nil)
              ("C-." . nil))
  :config
  (defun +flyspell-goto-previous-error ()
    "Go to the previous Flyspell error."
    (interactive)
    (flyspell-goto-next-error t))

  (setq flyspell-issue-message-flag nil
        flyspell-issue-welcome-flag nil
        flyspell-use-meta-tab nil
        flyspell-delay-use-timer t))


;; [ediff] Diff & patch
(use-package ediff
  :hook ((ediff-before-setup . +ediff-save-window-config)
         ((ediff-quit ediff-suspend) . +ediff-restore-window-config))
  :config
  ;; unfold outlines when using ediff
  (with-eval-after-load 'outline
    (add-hook! ediff-prepare-buffer-hook #'outline-show-all))

  ;; Restore window config after quitting ediff
  (defvar +ediff-saved-window-config nil)
  (defun +ediff-save-window-config ()
    (setq +ediff-saved-window-config (current-window-configuration)))
  (defun +ediff-restore-window-config ()
    (when (window-configuration-p +ediff-saved-window-config)
      (set-window-configuration +ediff-saved-window-config)))

  (setq ediff-window-setup-function 'ediff-setup-windows-plain
        ediff-split-window-function 'split-window-horizontally
        ediff-merge-split-window-function 'split-window-horizontally
        ediff-highlight-all-diffs t
        ;; turn off whitespace checking
        ediff-diff-options "-w"))


;; [elec-pair] Automatic parenthesis pairing
(use-package elec-pair
  :preface
  (defun +electric-pair-shell-setup ()
    "Pair delimiters within shell input fields, ignoring process output."
    (setq-local electric-pair-field-search-size 4096)
    (electric-pair-mode 1))
  :hook (((prog-mode conf-mode yaml-mode org-mode markdown-ts-mode minibuffer-mode) . electric-pair-mode)
         ((comint-mode eshell-mode) . +electric-pair-shell-setup)))


;; [mwim] Better C-a C-e for programming
(use-package mwim
  :straight t
  :bind (([remap move-beginning-of-line] . mwim-beginning-of-code-or-line)
         ([remap move-end-of-line] . mwim-end-of-code-or-line)))


;; [beginend] Better M-< M-> for programming
(use-package beginend
  :straight t
  :hook (after-init . beginend-global-mode)
  :config
  (beginend-define-mode telega-root-mode
    (progn
      (goto-char (max (point-min)
                      (1- telega-root-view--ewocs-marker)))
      (telega-button-forward 1 nil 'no-error))
    (progn
      (telega-button-backward 1 nil 'no-error)))

  ;; Install explicitly in case `beginend-global-mode' is already enabled.
  (add-hook! telega-root-mode-hook #'beginend-telega-root-mode))


;; Alternatives to [hungry-delete]
(setq backward-delete-char-untabify-method 'hungry)


;; [subword] Handling capitalized subwords
(use-package subword
  :hook (((prog-mode minibuffer-setup) . subword-mode)))


;; [easy-kill] Kill & Mark things easily, extends functionality of M-w
(use-package easy-kill
  :straight t
  :bind (([remap kill-ring-save] . easy-kill)
         ([remap mark-sexp] . easy-mark)))


;; [sudo-edit] edit file with su permissions
(use-package sudo-edit
  :straight t
  :config
  (sudo-edit-indicator-mode t))


;; [puni]
(use-package puni
  :straight t
  :hook ((prog-mode sgml-mode nxml-mode tex-mode eval-expression-minibuffer-setup) . puni-mode)
  :bind (:map puni-mode-map
              ("DEL" . +puni-hungry-delete))
  :config
  (defun +puni-hungry-delete ()
    (interactive)
    (if (looking-back "^[[:blank:]]+" (line-beginning-position))
        (let* ((puni-mode nil)
               (original-func (key-binding (kbd "DEL"))))
          ;; original-func is what `DEL' would be if puni-mode were disabled
          (if (eq original-func 'delete-backward-char)
              (backward-delete-char-untabify 1)
            (call-interactively original-func)))
      (puni-backward-delete-char))))

;; [dtdr-indent] Detect indentation size
(use-package dtrt-indent
  :straight t
  :hook (prog-mode . dtrt-indent-mode))
;; [expreg]
(use-package expreg
  :straight t
  :bind (("C-=" . expreg-expand)
         ("C--" . expreg-contract)))
;; [ialign] Interactive align
(use-package ialign
  :straight t)


;; [hideshow] Code folding
(use-package hideshow
  :preface
  (defun +hideshow-setup ()
    "Set up hideshow block definitions for modes that need overrides."
    (pcase major-mode
      ('ruby-mode
       ;; `ruby-forward-sexp' has been obsolete since 28.1.  With the
       ;; default SMIE grammar it only calls `forward-sexp'.
       (setq-local hs-block-start-regexp "class\\|d\\(?:ef\\|o\\)\\|module\\|[[{]"
                   hs-block-end-regexp "end\\|[]}]"
                   hs-c-start-regexp "#\\|=begin"
                   hs-forward-sexp-function #'forward-sexp))
      ('nxml-mode
       (setq-local hs-block-start-regexp "<!--\\|<[^/>]*[^/]>"
                   hs-block-end-regexp "-->\\|</[^/>]*[^/]>"
                   hs-c-start-regexp "<!--"
                   hs-forward-sexp-function #'sgml-skip-tag-forward))
      ((or 'latex-mode 'LaTeX-mode)
       (setq-local hs-block-start-regexp "\\\\begin{[a-zA-Z*]+}\\(\\)"
                   hs-block-start-mdata-select 1
                   hs-block-end-regexp "\\\\end{[a-zA-Z*]+}"
                   hs-c-start-regexp "%"
                   hs-forward-sexp-function
                   (lambda (_arg)
                     ;; LaTeX-find-matching-end needs to be inside the environment.
                     (unless (save-excursion
                               (search-backward "\\begin{document}"
                                                (line-beginning-position) t))
                       (LaTeX-find-matching-end)))))))
  :hook (((prog-mode conf-mode yaml-mode) . hs-minor-mode)
         ((ruby-mode nxml-mode latex-mode LaTeX-mode) . +hideshow-setup)
         ((yaml-mode) . hs-indentation-mode))
  :bind (("C-c TAB" . hs-cycle)
         ("C-c `" . hs-toggle-all))
  :config
  (setq hs-indicator-type nil
        hs-display-lines-hidden t))


;; [vundo] Undo tree
(use-package vundo
  :straight t
  :config
  (setq vundo-compact-display t
        vundo-roll-back-on-quit t))


;; [undohist] Persist undo history
(use-package undo-fu-session
  :straight t
  :hook (after-init . undo-fu-session-global-mode)
  :config
  (setq undo-fu-session-incompatible-files '("\\.gpg$" "/COMMIT_EDITMSG\\'" "/git-rebase-todo\\'"))

  (when (executable-find "zstd")
    ;; There are other algorithms available, but zstd is the fastest
    (setq undo-fu-session-compression 'zst)))


;; [undo-hl] Highlight undo changes
(use-package undo-hl
  :straight (:host github :repo "casouri/undo-hl")
  :hook (((prog-mode text-mode conf-mode) . undo-hl-mode)))


;; [re-builder]
(use-package re-builder
  :bind (:map reb-mode-map
              ("C-c C-k" . reb-quit)
              ("C-c C-p" . reb-prev-match)
              ("C-c C-n" . reb-next-match))
  :config
  (setq reb-re-syntax 'string))


;; [separedit]
(use-package separedit
  :straight t
  :bind (:map prog-mode-map
              ("C-c '" . separedit))
  :config
  (setq separedit-default-mode 'markdown-ts-mode))

;; [substitute] Replace targets across the buffer
(use-package substitute
  :straight t
  :bind ("C-c r" . substitute-prefix-map)
  :hook (substitute-post-replace . substitute-report-operation)
  :config
  (setopt substitute-highlight t)
  (setq substitute-fixed-letter-case nil))

;; [goto-chg] Jump to the last change
(use-package goto-chg
  :straight t
  :bind (("C-(" . goto-last-change)
         ("C-)" . goto-last-change-reverse)))

(provide 'init-edit)
