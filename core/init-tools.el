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


;; [ezf] Use Emacs completion from terminal shells
;; Consult's fd builder returns nil on a blank query (`when (or re opts)`).
;; Path tokens (~/, src/foo) were passed through as regexes and matched nothing.
(defun +ezf--fd-path-token-p (input)
  "Return non-nil when INPUT looks like a path prefix, not a cwd fuzzy query."
  (or (string-match-p "\\`\\(~\\|/\\|\\./\\|\\.\\./\\)" input)
      (string-search "/" input)))

(defun +ezf--fd-query-parts (input)
  "Return (DIR . PATTERN) for fd from Consult INPUT.
DIR is the absolute search root. PATTERN is never blank (Consult skips \"\")."
  (let ((cwd (file-name-as-directory (expand-file-name default-directory))))
    (cond
     ((string-blank-p input)
      (cons cwd "."))
     ((not (+ezf--fd-path-token-p input))
      (cons cwd input))
     (t
      (let ((expanded
             (ignore-errors
               (expand-file-name (substitute-in-file-name input) cwd))))
        (cond
         ((null expanded)
          (cons cwd "."))
         ((file-directory-p expanded)
          (cons (file-name-as-directory expanded) "."))
         (t
          (let ((dir (file-name-directory expanded))
                (base (file-name-nondirectory expanded)))
            (if (and dir (file-directory-p dir))
                (cons dir (if (string-blank-p base) "." base))
              (cons cwd input))))))))))

(defun +ezf--fd-format-candidate (candidate)
  "Turn an absolute fd line into a path that can replace the shell token."
  (let* ((abs (expand-file-name (string-remove-prefix "./" candidate)))
         (rel (file-relative-name abs default-directory)))
    (if (string-prefix-p ".." rel)
        (abbreviate-file-name abs)
      rel)))

(defun +ezf-fd-builder-list-on-empty (_orig directories-only)
  "Around `ezf--fd-builder': list on empty input; path prefixes search that directory."
  (lambda (input)
    (pcase-let* ((`(,dir . ,pattern) (+ezf--fd-query-parts input))
                 (path-prefix (+ezf--fd-path-token-p input))
                 (consult-fd-args
                  (append '("fd" "--full-path" "--absolute-path" "--color=never"
                            "--hidden" "--follow" "--exclude=.git")
                          (when path-prefix '("--max-depth=1"))
                          (when directories-only '("--type=directory"))))
                 (inner (consult--fd-make-builder (list dir))))
      (funcall inner pattern))))

(defun +ezf-fd-dispatch-source-format (orig directories-only context)
  "Around `ezf--fd-dispatch-source': insert cwd-relative or ~/ paths."
  (let ((source (funcall orig directories-only context)))
    (plist-put (copy-sequence source)
               :async
               (consult--process-collection
                (ezf--fd-builder directories-only)
                :min-input 0
                :transform (consult--async-map #'+ezf--fd-format-candidate)
                :highlight t))))

(defun +ezf-tab-insert ()
  "Insert the current Vertico candidate; stay in ezf. Directories get a trailing slash."
  (interactive)
  (vertico-insert)
  (let ((text (minibuffer-contents)))
    (when (and (not (string-suffix-p "/" text))
               (file-directory-p
                (expand-file-name (substitute-in-file-name text)
                                  default-directory)))
      (insert "/"))))

(defun +ezf-bind-tab-locally ()
  "In the ezf minibuffer, Tab completes the highlight instead of minibuffer-complete."
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map (current-local-map))
    (keymap-set map "TAB" #'+ezf-tab-insert)
    (keymap-set map "<tab>" #'+ezf-tab-insert)
    (use-local-map map)))

(defun +ezf-client-local-tab (orig request-file result-file)
  "Around `ezf-client': bind Tab only for this minibuffer."
  (minibuffer-with-setup-hook
      (:append #'+ezf-bind-tab-locally)
    (funcall orig request-file result-file)))

(use-package ezf
  :straight (:type git :host github :repo "roife/ezf")
  :demand t
  :config
  (advice-add #'ezf--fd-builder :around #'+ezf-fd-builder-list-on-empty)
  (advice-add #'ezf--fd-dispatch-source :around #'+ezf-fd-dispatch-source-format)
  (advice-add #'ezf-client :around #'+ezf-client-local-tab))


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
;; 2026-08-22: native DocState leak.  `reader-dyn--load-doc' mallocs with a
;; NULL user-ptr finalizer; `reader-refresh-doc-buffer' never calls
;; `set-visited-file-modtime' or `reader-dyn--close-doc'.  A rewritten PDF
;; stays stale forever; +auto-revert-mode + window churn re-loads it until
;; jetsam (pid 55552, 71GB).  Upstream kill-buffer-hook is also added
;; buffer-local at load time, not on reader-mode buffers.
(use-package reader
  :straight `(reader :type git :host codeberg :repo "MonadicSheep/emacs-reader"
                     :files (:defaults ,(concat "render-core" module-file-suffix))
                     ;; NOTE: Makefile shells out to `emacs' for checkdoc;
                     ;; init-straight.el ensures emacs is on PATH.
                     :pre-build ("make" "all"))
  :config
  (defun +reader-close-native-doc ()
    "Free the MuPDF DocState for this buffer.  Must run while overlays exist.
`reader-dyn--close-doc' no-ops unless the selected window has an overlay,
so iterate this buffer's windows instead of gating on `selected-window'."
    (when (and (derived-mode-p 'reader-mode)
               (fboundp 'reader-dyn--close-doc)
               (bound-and-true-p reader-current-doc-state-ptr))
      (dolist (window (get-buffer-window-list nil nil t))
        (when (and (bound-and-true-p reader-current-doc-state-ptr)
                   (reader-current-doc-overlay window))
          (with-selected-window window
            (reader-dyn--close-doc))))))

  (defadvice! +reader-refresh-close-before-reload-a (orig &rest args)
    :around #'reader-refresh-doc-buffer
    ;; close-doc no-ops if the overlay is already gone; call it before
    ;; upstream `remove-overlays'.
    (+reader-close-native-doc)
    (prog1 (apply orig args)
      (when buffer-file-name
        (set-visited-file-modtime)
        (set-buffer-modified-p nil))))

  (defun +reader-mode-setup ()
    "Stop polling auto-revert; free native memory when the buffer dies."
    (auto-revert-mode -1)
    (add-hook 'kill-buffer-hook #'+reader-close-native-doc nil t))
  (add-hook 'reader-mode-hook #'+reader-mode-setup)

  (with-eval-after-load 'zoom
    (when (boundp 'zoom-ignored-major-modes)
      (add-to-list 'zoom-ignored-major-modes 'reader-mode))))


;; [browse-url] Pass a URL to browser
(use-package browse-url
  :defines dired-mode-map
  :bind (("C-, o" . browse-url-at-point)
         ("C-, e" . browse-url-emacs))
  :config
  (setq browse-url-browser-function #'eww-browse-url))

;; [eww] Builtin browser
;; TTY: skip SHR images so kitty-graphics does not freeze on GitHub-sized
;; SVG pages.  GUI eww still shows images.  Toggle later with I.
(defun +eww-inhibit-images-on-tty ()
  "Set `shr-inhibit-images' on TTY frames only."
  (unless (display-graphic-p)
    (setq-local shr-inhibit-images t)))

;; Elfeed-show and eww both render HTML via SHR.  Default shr-text
;; inherits variable-pitch-text (Sarasa UI SC at 1.1×).  Use the
;; default face (TX-02) instead.
(use-package shr
  :config
  (setq shr-use-fonts nil
        shr-max-image-proportion 0.5))

(use-package eww
  :hook (eww-mode . +eww-inhibit-images-on-tty))

(use-package xwidget
  :config
  (setq xwidget-webkit-buffer-name-format "*XWidget: %T*"))
