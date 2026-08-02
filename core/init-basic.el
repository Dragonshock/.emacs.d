;;; -*- lexical-binding: t -*-

(use-package no-littering
  :straight (:host github :repo "emacscollective/no-littering")
  :demand t
  :config
  ;; `no-littering' intentionally leaves `custom-file' to the user.
  (setq custom-file (no-littering-expand-etc-file-name "custom.el")

        ;; Package-specific paths not covered by no-littering.
        tramp-rpc-deploy-local-cache-directory (no-littering-expand-var-file-name "tramp-rpc/")
        forge-post-fallback-directory (no-littering-expand-var-file-name "forge/drafts/")
        rust-playground-basedir (no-littering-expand-var-file-name "rust-playground/")
        typst-ts-lsp-download-path (no-littering-expand-var-file-name "lsp/tinymist/tinymist")
        chirp-cache-directory (no-littering-expand-var-file-name "chirp/")
        chirp-compose-temporary-directory (no-littering-expand-var-file-name "chirp/compose/")
        ghostel-module-directory (no-littering-expand-var-file-name "ghostel/"))

  ;; The existing configuration enables backups and auto-save.  This moves
  ;; them under `var/' as well.
  (no-littering-theme-backups)

  (dolist (directory
           (list tramp-rpc-deploy-local-cache-directory
                 forge-post-fallback-directory
                 rust-playground-basedir
                 chirp-cache-directory
                 chirp-compose-temporary-directory
                 ghostel-module-directory
                 (file-name-directory typst-ts-lsp-download-path)))
    (make-directory directory t)))

;; Never write numbered backups / auto-saves for credential-like paths
;; (align patterns with recentf / undo-fu-session excludes).
(defun +secret-file-p (file)
  "Return non-nil if FILE looks like a credential or secret path."
  (when file
    (let* ((name (expand-file-name file))
           (base (file-name-nondirectory name)))
      (or (string-match-p "\\.gpg\\'" name)
          (string-match-p "\\.authinfo\\(\\.gpg\\)?\\'" base)
          (string-equal base "authinfo.gpg")
          (string-match-p "\\.netrc\\'" base)
          (string-match-p "\\bcookies\\'" base)
          (string-match-p "\\.pat\\'" base)
          (string-match-p "gh\\.pat\\'" base)
          (string-match-p "/\\.cli-proxy-api/" name)
          (string-match-p "/\\.ssh/" name)
          (member base '("id_rsa" "id_ed25519" "passwd" "credentials"))))))

(setq backup-enable-predicate
      (lambda (name)
        (and (normal-backup-enable-predicate name)
             (not (+secret-file-p name)))))

(defun +maybe-disable-auto-save-for-secrets ()
  "Turn off auto-save when visiting a secret file."
  (when (and buffer-file-name (+secret-file-p buffer-file-name))
    (auto-save-mode -1)
    (setq buffer-auto-save-file-name nil)))
(add-hook 'find-file-hook #'+maybe-disable-auto-save-for-secrets)

(setq-default
 ;; no client startup messages
 server-client-instructions nil

 ;; Files
 ;; [lockfile]
 create-lockfiles nil
 ;; [backup]
 vc-make-backup-files t
 version-control t
 backup-by-copying t
 delete-old-versions t
 kept-new-versions 6
 ;; [auto-save] stock auto-save-default is already t; keep big-deletion override only.
 auto-save-include-big-deletions t ; Don't auto-disable auto-save after deleting big chunks.

 ;; Disable [bidirectional text] scanning for a modest performance
 ;; Will improve long line display performance
 bidi-inhibit-bpa t
 bidi-paragraph-direction 'left-to-right

 ;; Leave long-line-threshold / large-hscroll-threshold / syntax-wholeline-max
 ;; at stock defaults (DOC: do not lower except for debugging; stock ~50000 /
 ;; 10000). Rely on global-so-long-mode + bidi settings for long lines.

 ;; Larger process output buffer for LSP module
 read-process-output-max (* 4 1024 1024)

 ;; [Wrapping] words at whitespace, but do not wrap by default
 ;; Wrap words at whitespace, rather than in the middle of a word.
 word-wrap t
 ;; don't do any wrapping by default since it's expensive
 truncate-lines t
 truncate-partial-width-windows nil
 ;; better wrapping for cjk
 word-wrap-by-category t

 ;; Always follow link when visiting a [symbolic link]
 find-file-visit-truename t
 vc-follow-symlinks t

 ;; Case insensitive completion
 read-buffer-completion-ignore-case t
 read-file-name-completion-ignore-case t

 ;; disable [bell] completely
 ring-bell-function 'ignore

 ;; Disable copy region blink
 copy-region-blink-delay 0
 delete-pair-blink-delay 0

 ;; set [fill column] indicator to 80
 fill-column 80

 ;; [tab]
 ;; Make `tabify' only affect indentation
 tabify-regexp "^\t* [ \t]+"
 ;; Indent with 4 space by default
 indent-tabs-mode nil
 ;; Indent first; when already indented, run completion-at-point (Tempel/cape via TAB).
 ;; Symbol `complete' is required — plain `t' is the stock default and never reaches capf.
 tab-always-indent 'complete
 tab-width 4

 ;; Sentence end
 sentence-end "\\([。！？]\\|……\\|[.?!][]\"')}]*\\($\\|[ \t]\\)\\)[ \t\n]*"
 sentence-end-double-space nil

 ;; Use y-or-n to replace yes-or-no
 use-short-answers t
 ;; Inhibit switching out from `y-or-n-p' and `read-char-choice'
 y-or-n-p-use-read-key t
 read-char-choice-use-read-key t

 ;; Don't ping things that look like domain names.
 ffap-machine-p-known 'reject

 ;; Disable the "same file" warning, just redirect to the existing buffer
 find-file-suppress-same-file-warnings t

 ;; POSIX standard [newline]
 require-final-newline t

 ;; Don't prompt for confirmation when creating a new file or buffer
 confirm-nonexistent-file-or-buffer nil

 ;; Show path/name if names are same
 uniquify-buffer-name-style 'forward

 ;; Fix alignment problem
 truncate-string-ellipsis "…"

 ;; Shell command
 shell-command-prompt-show-cwd t

 ;; What-cursor-position
 what-cursor-show-names t

 ;; List only applicable commands
 read-extended-command-predicate #'command-completion-default-include-p
 )

;; Enable [disabled cmds]
;; Enable the disabled narrow commands
(put 'narrow-to-defun  'disabled nil)
(put 'narrow-to-page   'disabled nil)
(put 'narrow-to-region 'disabled nil)

;; Enable the disabled dired commands
(put 'dired-find-alternate-file 'disabled nil)

;; Enable the disabled `list-timers', `list-threads' commands
(put 'list-timers 'disabled nil)
(put 'list-threads 'disabled nil)

;; Quick editing in `describe-variable'
(with-eval-after-load 'help-fns
  (put 'help-fns-edit-variable 'disabled nil))


;; [autosave]
;; TRICK: If a file has autosaved data, `after-find-file' will pause for 1 second to
;; tell about it, which is very annoying. Just disable it.
(defadvice! +disable-autosave-notification-a (fn &rest args)
  :around #'after-find-file
  (cl-letf (((symbol-function #'sit-for) #'ignore))
    (apply fn args)))


;; Encoding & locale
(set-locale-environment "en_US.UTF-8")
(prefer-coding-system 'utf-8-unix)
(setq-default default-input-method nil)
(setq system-time-locale "C")

(add-hook! (tty-setup-hook server-after-make-frame-hook)
  (defun +setup-tty-coding-system (&optional frame)
    "Use UTF-8 for keyboard input and terminal output in TTY frames."
    (let ((frame (or frame (selected-frame))))
      (unless (display-graphic-p frame)
        (set-keyboard-coding-system 'utf-8-unix frame)
        (set-terminal-coding-system 'utf-8-unix frame t)))))


;; [gcmh] Run GC when Emacs is idle, not while commands are active.
(use-package gcmh
  :straight t
  :unless (fboundp 'igc-info)
  :hook (emacs-startup . gcmh-mode)
  :config
  (setq gcmh-idle-delay 'auto
        gcmh-auto-idle-delay-factor 10
        gcmh-high-cons-threshold (* 128 1024 1024)
        gcmh-low-cons-threshold +gc-cons-threshold))


;; History
;;; [save-place-mode] save place lastly visited
(use-package saveplace
  :hook (after-init . save-place-mode)
  :config
  (setopt save-place-autosave-interval 1000)

  ;; Align with +secret-file-p / recentf / undo-fu: never record point in
  ;; credential paths (path+offset still leak via places file / sync).
  ;; Include cookies/passwd/credentials basenames (same as +secret-file-p).
  (setopt save-place-ignore-files-regexp
          (concat "\\(?:"
                  (or (default-value 'save-place-ignore-files-regexp)
                      "\\`/tmp/")
                  "\\)\\|"
                  "\\.gpg\\'\\|"
                  "/\\.authinfo\\(\\.gpg\\)?\\'\\|"
                  "authinfo\\.gpg\\'\\|"
                  "\\.netrc\\'\\|"
                  "/\\.ssh/\\|"
                  "\\bid_rsa\\b\\|"
                  "\\bid_ed25519\\b\\|"
                  "\\.pat\\'\\|"
                  "gh\\.pat\\'\\|"
                  "/\\.cli-proxy-api/\\|"
                  "\\bcookies\\'\\|"
                  "\\bpasswd\\'\\|"
                  "\\bcredentials\\'"))

  ;; Emacs 31 `save-place-alist-to-file' already uses `prin1' (no `pp'); no advice needed.

  ;; Recenter after restore (Emacs 29+: public hook, not advice on finder).
  (add-hook 'save-place-after-find-file-hook
            (lambda ()
              (when buffer-file-name (ignore-errors (recenter)))))
  )


;;; [recentf] recently visited files
(use-package recentf
  :bind (("C-x C-r" . recentf-open-files))
  :hook (after-init . recentf-mode)
  :config
  (setopt recentf-autosave-interval 1000)

  ;; Cleanup periodically (not `never`): secrets/ephemeral paths should not linger.
  ;; Align secret patterns with `undo-fu-session-incompatible-files' (init-tools).
  (setq recentf-auto-cleanup 3600
        recentf-max-saved-items 200
        recentf-exclude (list "\\.?cache" ".cask" "url" "COMMIT_EDITMSG\\'" "bookmarks"
                              "\\.?ido\\.last$" "\\.revive$" "/G?TAGS$"
                              ;; Elfeed db is `elfeed/' (no leading dot); also excluded
                              ;; via predicate in init-elfeed.el.
                              "/elfeed/"
                              "^/tmp/" "/private/tmp/"
                              "^/var/folders/.+$" "^/ssh:"
                              "\\.gpg$"
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
                              "passwd"
                              "credentials"
                              (lambda (file) (file-in-directory-p file package-user-dir))
                              (recentf-expand-file-name no-littering-var-directory)
                              (recentf-expand-file-name no-littering-etc-directory)
                              (expand-file-name recentf-save-file))
        recentf-keep nil)

  ;; Emacs 29.1+ already defaults `recentf-filename-handlers' to
  ;; '(abbreviate-file-name); only strip text properties for cache size.
  ;; HACK: Text properties inflate the size of recentf's files, and there is
  ;; no purpose in persisting them (Must be first in the list!)
  (add-to-list 'recentf-filename-handlers #'substring-no-properties)

  ;; Add dired directories to recentf file list.
  (add-hook! dired-mode-hook
    (defun +dired--add-to-recentf-h ()
      (recentf-add-file default-directory)))
  )


;;; [savehist] Save variables to file
(use-package savehist
  :hook (after-init . savehist-mode)
  :config
  ;; Do not persist `kill-ring': yanks can contain passwords/tokens and would
  ;; land in var/savehist.el (mode 600 is not enough if the file is synced).
  ;; MERGE LOCK: never re-add kill-ring from roife/.emacs.d (audit keep-local).
  ;;
  ;; Do not persist `dogears-list': each place stores full source line (`line')
  ;; and can leak secrets even after path filters.  Align with dogears README
  ;; (intentionally non-persistent).  Session dogears still work in-memory.
  ;;
  ;; Do not half-register `vertico-repeat-history' without vertico-repeat-save
  ;; on minibuffer-setup-hook (silent-nop dead config).
  (setq savehist-additional-variables '(global-mark-ring
                                        search-ring
                                        regexp-search-ring)
        savehist-autosave-interval 1000)

  (defadvice! +savehist-clean-values-a (save &rest args)
    :around #'savehist-save
    ;; Scrub secrets from path-like history (minibuffer add-to-history bypasses
    ;; find-file-hook).  Align with +secret-file-p / recentf / save-place.
    (let ((search-ring (mapcar #'substring-no-properties search-ring))
          (regexp-search-ring (mapcar #'substring-no-properties regexp-search-ring))
          (file-name-history
           (seq-remove (lambda (f)
                         (and (stringp f) (+secret-file-p f)))
                       file-name-history)))
      (apply save args))))


;; [so-long] Workaround for long one-line file
(use-package so-long
  :hook ((after-init . global-so-long-mode))
  :config
  (dolist (mode '(conf-mode text-mode))
    (add-to-list 'so-long-target-modes mode))

  (dolist (mode '(font-lock-mode
                  eldoc-mode
                  flymake-mode
                  ws-butler-mode
                  auto-composition-mode))
    (add-to-list 'so-long-minor-modes mode))

  ;; Do not set bidi-display-reordering to nil (debug-only / unsupported).
  ;; Rely on bidi-paragraph-direction, bidi-inhibit-bpa, and long-line-threshold.
  ;; Do not override `save-place-alist': so-long makes overrides buffer-local, and
  ;; that shadows the session-global alist so so-long buffers never persist point.
  (add-to-list 'so-long-variable-overrides '(font-lock-maximum-decoration . 1))
  )


;; [glyphless-display] — DO NOT enable globally.
;;
;; Upstream roife/.emacs.d hooks only (after-init . glyphless-display-mode),
;; which almost only affects *scratch* at startup.  A previous local "fix"
;; used after-change-major-mode so EVERY buffer got glyphless-display-mode
;; with glyphless-mode-types default (all) → C1 controls show as [PAD] etc.
;; and characters without a font (icon PUA, some symbols) show as hex/acronym
;; boxes instead of glyphs.  That is the (PAD..\377) / "icons don't render"
;; class of bugs.
;;
;; Perfect policy: leave stock display; use M-x glyphless-display-mode only
;; when debugging invisible control characters.  Optional toggle:
(defun +glyphless-display-toggle ()
  "Toggle `glyphless-display-mode' in the current buffer (debug)."
  (interactive)
  (if (bound-and-true-p glyphless-display-mode)
      (glyphless-display-mode -1)
    (setq-local glyphless-mode-types '(c0-control c1-control bidi-control))
    (glyphless-display-mode 1)))

;; [Scrolling]
(setq
 ;; Performant and rapid scrolling
 fast-but-imprecise-scrolling t

 ;; Keep 5 lines when scrolling
 scroll-step 0
 scroll-margin 3
 scroll-up-aggressively 0.01 ; less jumpy
 scroll-down-aggressively 0.01
 scroll-conservatively 101
 ;; Reduce cursor lag by a tiny bit by not auto-adjusting `window-vscroll' for tall lines.
 auto-window-vscroll nil

 ;; [hscroll]
 auto-hscroll-mode t
 hscroll-step 0
 hscroll-margin 2)

(defvar +scrolling-lines 10)
(defun +scroll-other-window () (interactive) (scroll-other-window +scrolling-lines))
(defun +scroll-other-window-down () (interactive) (scroll-other-window-down +scrolling-lines))
(defun +scroll-window () (interactive) (scroll-up +scrolling-lines))
(defun +scroll-window-down () (interactive) (scroll-down +scrolling-lines))
;; Prefer global-map over bind-keys*/override-global-map so major-mode maps
;; (e.g. elfeed-show M-v → scroll-down-command) still win.
(bind-keys
 ("C-M-v" . +scroll-other-window)
 ("M-<down>" . +scroll-other-window)

 ("C-M-S-v" . +scroll-other-window-down)
 ("M-<up>" . +scroll-other-window-down)

 ("C-v" . +scroll-window)
 ("M-v" . +scroll-window-down))


;; [tramp] Edit file remotely
(use-package tramp
  :config
  (setq tramp-default-method "ssh"
        tramp-backup-directory-alist backup-directory-alist
        remote-file-name-inhibit-cache 60))


(use-package tramp-rpc
  :straight (:type git
                   :host github
                   :repo "ArthurHeymans/emacs-tramp-rpc")
  :after tramp
  :config
  ;; Default git policy is `auto' (cargo-build from source tree).  `release'
  ;; is only for forced prebuilt binaries and skews with git-installed Lisp.
  (setq tramp-rpc-deploy-auto-deploy t
        tramp-rpc-deploy-git-build-policy 'auto))


;; [minibuffer]
(use-package minibuffer
  ;; These are minor-mode commands: setting them with `setq' never activated
  ;; them.  `minibuffer-depth-indicate-mode' is already enabled via the
  ;; mb-depth hook in init-ui.el.
  :hook (after-init . minibuffer-electric-default-mode)
  :config
  (setq minibuffer-default-prompt-format " [%s]" ; shorten " (default %s)" => " [%s]"
        ;; One frame one minibuffer.
        minibuffer-follows-selected-frame nil))


;; [repeat] Enable repeatable commands
(use-package repeat
  :straight nil
  :hook (after-init . repeat-mode))


;; [comint] Command interpreter
(use-package comint
  :config
  (setq comint-prompt-read-only t
        comint-buffer-maximum-size 2048

        ;; No paging, `eshell' and `shell' will honoring.
        comint-pager "cat"

        ;; better history search
        comint-history-isearch 'dwim))


;; [environment variables]
;; Run `exec-path-from-shell-initialize' at most once (after-init).  Do not
;; permanently `:unless' on (daemonp): emacs-plus site-start only injects PATH
;; via EMACS_PLUS_PATH / ns-emacs-plus-injected-path, not JAVA_HOME /
;; JDTLS_JAVA_HOME / MANPATH / HOMEBREW.  Daemon + emacsclient needs those.
;; Non-daemon pure TTY sessions skip the login-shell probe.  Avoid a second
;; call from :config — use-package-always-defer used to re-run initialize and
;; spawn an extra shell on every graphical startup.
(use-package exec-path-from-shell
  :straight t
  :unless noninteractive
  :init
  (setq exec-path-from-shell-arguments '("-l")
        exec-path-from-shell-variables
        (let ((vars '("HOMEBREW" "JAVA_HOME" "JDTLS_JAVA_HOME" "MANPATH")))
          (if (bound-and-true-p ns-emacs-plus-injected-path)
              vars
            (cons "PATH" vars))))
  (defvar +exec-path-from-shell--initialized nil
    "Non-nil after `exec-path-from-shell-initialize' has run once this session.")
  (defun +exec-path-from-shell-maybe-initialize ()
    "Copy shell env once for GUI frames or Emacs daemon sessions."
    (unless +exec-path-from-shell--initialized
      (when (or (daemonp) (display-graphic-p))
        (require 'exec-path-from-shell)
        (exec-path-from-shell-initialize)
        (setq +exec-path-from-shell--initialized t))))
  :hook (after-init . +exec-path-from-shell-maybe-initialize))


;; backup-walker (2013) is unmaintained and uses obsolete cl / easy-mmode-defmap /
;; point-at-bol.  Prefer built-in `diff-backup' / `file-newest-backup' / VC.


;; [info] Add local Info manuals after system dirs (do not replace Info-directory-list;
;; a non-nil list skips info-initialize's INFOPATH/system path merge).
(use-package info
  :config
  (add-to-list 'Info-additional-directory-list
               (expand-file-name "~/Documents/Info")))
