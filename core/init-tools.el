;;; -*- lexical-binding: t -*-

;; [isearch] Use builtin isearch to replace `anzu'
(use-package isearch
  :bind (:map isearch-mode-map
              ([remap isearch-delete-char] . isearch-del-char))
  :config
  (setq
   ;; Record isearch in minibuffer history, so C-x ESC ESC can repeat it.
   isearch-resume-in-command-history t
   ;; isearch-lax-whitespace stock default is already t (Emacs 25.1+).
   ;; direction change
   isearch-repeat-on-direction-change t
   ;; M-< and M-> move to the first/last occurrence of the current search string.
   isearch-allow-motion t
   isearch-motion-changes-direction t
   ;; lazy-count
   isearch-lazy-count t
   lazy-highlight-cleanup nil
   lazy-highlight-buffer t
   ;; search-ring
   search-ring-max 200
   regexp-search-ring-max 200))


;; [speedbar]
(use-package speedbar
  :init
  (setq speedbar-prefer-window t
        speedbar-window-default-width 30))


;; [goto-addr] Click to open URL
(use-package goto-addr
  :hook ((text-mode . goto-address-mode)
         (prog-mode . goto-address-prog-mode)))


;; [arxiv.el] Search, browse, and save arXiv papers
;; (use-package arxiv
;;   :straight (:type git :host github :repo "roife/arxiv.el")
;;   :config
;;   (setq arxiv-browser-function #'arxiv-eww-browse-url)
;;   (arxiv-url-handler-mode 1))


;; [avy] Jump with several key strock
(use-package avy
  :straight t
  :bind (("C-, ." . avy-goto-char)
         ("C-, ," . avy-goto-char-2)
         ("C-, l" . avy-goto-line)
         :map isearch-mode-map
         ("C-, ," . avy-isearch))
  :config
  ;; overlay is used during isearch, `pre' style makes avy keys evident.
  (setq avy-styles-alist '((avy-isearch . pre))))


;; [link-hint] Open URL in text with avy
(use-package link-hint
  :straight t
  :bind
  ("C-, j" . link-hint-open-link)
  ("C-, c" . link-hint-copy-link))


;; [ialign] Interactive align
(use-package ialign
  :straight t)


;; [hideshow] Code folding
(use-package hideshow
  :preface
  (defun +hideshow-setup ()
    "Set up hideshow block definitions for modes that need overrides.
Ruby uses treesit (`ruby-ts-mode`) + prog-mode hs; no special ruby arm."
    (pcase major-mode
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
  ;; toml-ts-mode derives from text-mode (not conf-mode); with
  ;; treesit-enabled-modes remapping conf-toml → toml-ts, conf-mode-hook never
  ;; runs for .toml — list toml-ts-mode explicitly (same pattern as yaml-ts).
  ;; nxml/latex/LaTeX derive from text-mode (not prog/conf) — must list them on
  ;; hs-minor-mode or setup-only hooks leave folding as a silent no-op.
  :hook (((prog-mode conf-mode yaml-mode yaml-ts-mode toml-ts-mode
                     nxml-mode latex-mode LaTeX-mode)
          . hs-minor-mode)
         ((nxml-mode latex-mode LaTeX-mode) . +hideshow-setup)
         ;; Indentation-style hs is for classic yaml-mode; treesit yaml uses
         ;; treesit-hs predicates from major-mode setup — keep yaml-ts off here.
         ((yaml-mode) . hs-indentation-mode))
  :bind (("C-c h TAB" . hs-cycle)
         ("C-c h `" . hs-toggle-all))
  :config
  ;; Leave `hs-show-indicators' at default nil; do not set `hs-indicator-type'
  ;; alone (it only applies when indicators are enabled).
  (setq hs-display-lines-hidden t))


;; [project] Project manager (Emacs 31 built-in; do not pull ELPA clone)
(use-package project
  :straight (:type built-in)
  ;; Ghostel takes C-x p m/M (dakra README). Magit uses v (VCS).
  :bind (:map project-prefix-map
              ("v" . magit-status))
  :config
  ;; Third element is the dispatch KEY (required for a working switch menu).
  ;; Ghostel lives here (not only init-ghostel add-to-list): this setq would
  ;; otherwise clobber after-load additions from earlier modules.
  (setq project-switch-commands '((project-find-file "File" ?f)
                                  (project-find-regexp "Regexp" ?g)
                                  (project-switch-to-buffer "Buffer" ?b)
                                  (project-dired "Dired" ?d)
                                  (project-eshell "Eshell" ?e)
                                  (project-search "Search" ?s)
                                  (ghostel-project "Ghostel" ?m)
                                  (ghostel-project-list-buffers "Ghostel buffers" ?M)
                                  (magit-status "Magit" ?v)))

  )


;; [vundo] Undo tree
(use-package vundo
  :straight t
  :config
  ;; vundo-roll-back-on-quit stock package default is already t.
  (setq vundo-compact-display t))


;; [undohist] Persist undo history
(use-package undo-fu-session
  :straight t
  :hook (after-init . undo-fu-session-global-mode)
  :config
  ;; Never snapshot secrets or ephemeral credentials (regexps match full path).
  (setq undo-fu-session-incompatible-files
        '("\\.gpg$"
          "/COMMIT_EDITMSG\\'"
          "/git-rebase-todo\\'"
          "/\\.authinfo\\(\\.gpg\\)?\\'"
          "/authinfo\\.gpg\\'"
          "\\.netrc\\'"
          "/cookies\\'"
          "\\.pat\\'"
          "/gh\\.pat\\'"
          "/\\.cli-proxy-api/"
          "/\\.ssh/"
          "id_rsa"
          "id_ed25519"
          "/private/tmp/"
          "^/tmp/"
          "passwd"
          "credentials"))

  (when (executable-find "zstd")
    ;; There are other algorithms available, but zstd is the fastest
    (setq undo-fu-session-compression 'zst)))


;; [undo-hl] Highlight undo changes (buffer-local; not global after-init)
(use-package undo-hl
  :straight (:host github :repo "casouri/undo-hl")
  :hook ((prog-mode text-mode conf-mode) . undo-hl-mode)
  :config (setq undo-hl-flash-duration 0.1))


;; [imenu] Jump to function definitions
(use-package imenu
  :commands (imenu--make-index-alist)
  :hook ((prog-mode conf-mode yaml-mode markdown-ts-mode org-mode) . (lambda () (imenu--make-index-alist t))))


;; [re-builder]
(use-package re-builder
  :straight nil
  :commands re-builder
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
  ;; separedit only wires nested fenced-block edit for markdown-mode / gfm-mode.
  (setq separedit-default-mode 'markdown-mode))


;; [emacs-reader] read docs in emacs (moved here from init-pdf.el, upstream layout)
(use-package reader
  :straight '(reader :type git :host codeberg :repo "MonadicSheep/emacs-reader"
                     :files ("*.el" "render-core.dylib")
                     ;; NOTE: Makefile shells out to `emacs' for checkdoc;
                     ;; init-straight.el ensures emacs is on PATH.
                     :pre-build ("make" "all")))


;; [browse-url] Pass a URL to browser
(use-package browse-url
  :defines dired-mode-map
  :bind (("C-, o" . browse-url-at-point)
         ("C-, e" . browse-url-emacs))
  :config
  (setq browse-url-browser-function #'eww-browse-url))

;; [eww] Builtin browser
(use-package eww
  :config
  (setq shr-max-image-proportion 0.5))

(use-package xwidget
  :config
  (setq xwidget-webkit-buffer-name-format "*XWidget: %T*"))
