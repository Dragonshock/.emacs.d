;;; -*- lexical-binding: t -*-

;; [dired] File manager
(use-package dired
  :bind (:map dired-mode-map
              ("C-c C-p" . wdired-change-to-wdired-mode))
  :config
  (setq
   ;; dired-recursive-deletes stock default is already 'top.
   dired-recursive-copies 'always
   ;; Move between two dired buffer quickly
   dired-dwim-target t
   ;; dired-create-destination-dirs set once in dired-aux (with vc-rename).
   ;; don't prompt to revert, just do it
   ;; Predicate must accept DIRNAME; `dired-buffer-stale-p' is for Auto Revert.
   dired-auto-revert-buffer #'dired-directory-changed-p
   ;; symlink
   dired-hide-details-hide-symlink-targets nil
   ;; free disk
   dired-free-space nil
   )

  ;; Emacs 30.1+ stock `insert-directory-program' is computed via
  ;; custom-initialize-delay *before* site-start.  On emacs-plus GUI
  ;; launches, EMACS_PLUS_PATH is injected only in site-start, so the
  ;; stock default often freezes as "ls" even when gls exists.  Re-bind
  ;; here (user init runs after site-start).  Use an absolute path so
  ;; later PATH changes cannot reintroduce BSD ls.
  (cond
   ((and (eq system-type 'darwin) (executable-find "gls"))
    (setq insert-directory-program (executable-find "gls")
          dired-listing-switches "-alh --group-directories-first"))
   ((eq system-type 'darwin)
    ;; BSD ls only: no GNU long options, no --dired.
    (setq dired-use-ls-dired nil
          dired-listing-switches "-alh"))
   (t
    (setq dired-listing-switches "-alh --group-directories-first")))
  )

;; [dired-git-info] Show git info in dired
(use-package dired-git-info
  :straight t
  :after dired
  :bind (:map dired-mode-map
              ("G" . dired-git-info-mode))
  :config
  (setq dgi-commit-message-format "%h %cs %s"
        dgi-auto-hide-details-p nil)
  )

;; [dired-aux] Extra Dired functionality
(use-package dired-aux
  :after dired
  :config
  (setq dired-create-destination-dirs 'ask
        dired-vc-rename-file t))


;; [dired-x] Extra Dired functionality
(use-package dired-x
  :after dired
  :bind (:map dired-mode-map
              ("." . dired-omit-mode))
  :config
  (setq dired-omit-verbose nil
        ;; hide dot files
        dired-omit-files "^\\..*\\'")

  ;; Disable the prompt about killing the Dired buffer for a deleted directory.
  (setq dired-clean-confirm-killing-deleted-buffers nil)
  )


;; [fd-dired] Using `fd' with `find-dired'
(use-package fd-dired
  :straight t
  :bind ([remap find-dired] . fd-dired))


;; [dired-hacks] Several additional extensions for dired
(use-package dired-hacks
  :straight (:host github :repo "roife/dired-hacks" :branch "fix/collapse-subtree")
  :after dired
  :init
  (use-package dired-subtree
    :bind (:map dired-mode-map
                ("TAB" . dired-subtree-toggle))
    :config
    (setq dired-subtree-line-prefix "  |  "))

  (use-package f :straight t :demand t)

  (use-package dired-collapse
    :custom-face
    (dired-collapse-shadow ((t (:inherit diredfl-dir-name))))
    :hook (dired-mode . dired-collapse-mode))

  (use-package dired-narrow
    :bind (:map dired-mode-map
                (";" . dired-narrow-fuzzy)))
  )


;; [ffx] `dired-collapse'-style folding for file-name completion.
;; When a directory holds a single sub-directory chain (ignoring the same
;; entries `dired-omit-mode' hides), offer an extra candidate that jumps
;; straight to the end of the chain, alongside the normal one-level candidate.
;; e.g. when "a/" only ever contains "a/b/c/d/", both show up:
;;   a/
;;   a/b/c/d/
(use-package ffx
  :straight (:host github :repo "roife/ffx.el")
  :hook (after-init . ffx-mode))


;; [diredfl] Make dired colorful
(use-package diredfl
  :straight t
  :hook (dired-mode . diredfl-mode))
