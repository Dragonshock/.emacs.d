;;; -*- lexical-binding: t -*-

(use-package no-littering
  :straight (:host github :repo "emacscollective/no-littering")
  :demand t
  :config
  ;; The existing configuration enables backups and auto-save.  This moves
  ;; them under `var/' as well.
  (no-littering-theme-backups))

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
 ;; [auto-save]
 auto-save-default t
 auto-save-include-big-deletions t ; Don't auto-disable auto-save after deleting big chunks.

 ;; Disable [bidirectional text] scanning for a modest performance
 ;; Will improve long line display performance
 bidi-inhibit-bpa t
 bidi-paragraph-direction 'left-to-right
 bidi-display-reordering nil

 ;; smaller threshold to improve long line performance
 long-line-threshold 1000
 large-hscroll-threshold 1000
 syntax-wholeline-max 1000

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
 ;; Always indent with TAB.
 tab-always-indent t
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
 truncate-string-ellipsis "›"

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


;; History
;;; [save-place-mode] save place lastly visited
(use-package saveplace
  :hook (after-init . save-place-mode)
  :config
  ;; The :set function arms the timer, but only while the mode is on.
  ;; `setq' stores the number and never calls it.
  (add-hook 'save-place-mode-hook
            (defun +save-place-set-autosave-interval-h ()
              (when save-place-mode
                (setopt save-place-autosave-interval 1000))))

  ;; Avoid autoloading TRAMP when normalizing saved remote paths, while keeping
  ;; other file name handlers active.
  (defadvice! +save-place-inhibit-tramp-autoload-a (fn &rest args)
    :around #'save-place--normalize-alist
    (let ((file-name-handler-alist
           (cl-remove-if
            (lambda (handler)
              (eq (cdr handler) 'tramp-autoload-file-name-handler))
            file-name-handler-alist)))
      (apply fn args)))

  ;; recenters the view after the jump
  (defadvice! +save-place-recenter-a (&rest _)
    :after #'save-place-find-file-hook
    (when buffer-file-name (ignore-errors (recenter)))))


;;; [recentf] recently visited files
(use-package recentf
  :bind (("C-x C-r" . recentf-open-files))
  :hook (after-init . recentf-mode)
  :config
  ;; Both :set functions install timers, and only while the mode is on.
  ;; `setq' leaves them idle.
  (add-hook 'recentf-mode-hook
            (defun +recentf-set-autosave-options-h ()
              (when recentf-mode
                (setopt recentf-autosave-interval 1000
                        recentf-auto-cleanup 'never))))
  (setq recentf-max-saved-items 200
        recentf-exclude (list "\\.?cache" ".cask" "url" "COMMIT_EDITMSG\\'" "bookmarks"
                              "\\.?ido\\.last$" "\\.revive$" "/G?TAGS$" "/.elfeed/"
                              "^/tmp/" "^/var/folders/.+$" "^/ssh:"
                              (lambda (file) (file-in-directory-p file package-user-dir))
                              (recentf-expand-file-name no-littering-var-directory)
                              (recentf-expand-file-name no-littering-etc-directory)
                              (expand-file-name recentf-save-file))
        recentf-keep nil)

  (add-to-list 'recentf-filename-handlers #'abbreviate-file-name)

  ;; HACK: Text properties inflate the size of recentf's files, and there is
  ;; no purpose in persisting them (Must be first in the list!)
  (add-to-list 'recentf-filename-handlers #'substring-no-properties)

  ;; Add dired directories to recentf file list.
  (add-hook! dired-mode-hook
    (defun +dired--add-to-recentf-h ()
      (recentf-add-file default-directory))))


;;; [savehist] Save variables to file
(use-package savehist
  :hook (after-init . savehist-mode)
  :config
  (setq savehist-additional-variables '(kill-ring
                                        global-mark-ring
                                        search-ring
                                        regexp-search-ring
                                        dogears-list))
  ;; `savehist-mode' first installs the default 300s timer.  :set replaces it;
  ;; `setq' does not.
  (add-hook 'savehist-mode-hook
            (defun +savehist-set-autosave-interval-h ()
              (when savehist-mode
                (setopt savehist-autosave-interval 1000))))

  (with-eval-after-load 'vertico
    (add-to-list 'savehist-additional-variables 'vertico-repeat-history))

  (defvar dogears-list nil)
  (defun +dogears--record-for-savehist (record)
    (cons (substring-no-properties (car record))
          (mapcar
           (lambda (item)
             (pcase item
               (`(buffer . ,buffer)
                (if (bufferp buffer)
                    (cons 'buffer (buffer-name buffer))
                  item))
               (_ item)))
           (cdr record))))

  (defadvice! +savehist-clean-values-a (save &rest args)
    :around #'savehist-save
    (let ((kill-ring (mapcar #'substring-no-properties kill-ring))
          (search-ring (mapcar #'substring-no-properties search-ring))
          (regexp-search-ring (mapcar #'substring-no-properties regexp-search-ring))
          (dogears-list (mapcar #'+dogears--record-for-savehist dogears-list)))
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
                  auto-composition-mode
                  diff-hl-mode
                  display-fill-column-indicator-mode
                  goggles-mode
                  highlight-changes-mode
                  highlight-parentheses-mode
                  hl-line-mode
                  indent-bars-mode
                  flyspell-mode
                  ligature-mode
                  prettify-symbols-mode
                  rainbow-delimiters-mode
                  scrollview-mode
                  symbol-overlay-mode
                  whitespace-mode))
    (add-to-list 'so-long-minor-modes mode))

  (dolist (override '((bidi-display-reordering . nil)
                      (font-lock-maximum-decoration . 1)
                      (save-place-alist . nil)))
    (add-to-list 'so-long-variable-overrides override)))


;; [glyphless-display] Don't render glyphs, in case of undisplayable characters.
(use-package glyphless-mode
  :hook (after-init . glyphless-display-mode))

;; [Scrolling]
(setq
 ;; Performant and rapid scrolling
 fast-but-imprecise-scrolling t

 ;; Keep 5 lines when scrolling
 scroll-step 6
 scroll-margin 6
 scroll-up-aggressively 0.25
 scroll-down-aggressively 0.25
 ;; Reduce cursor lag by a tiny bit by not auto-adjusting `window-vscroll' for tall lines.
 auto-window-vscroll t

 ;; [hscroll]
 auto-hscroll-mode t
 hscroll-step 0.3
 hscroll-margin 6)

(defvar +scrolling-lines 10)
(defun +scroll-other-window () (interactive) (scroll-other-window +scrolling-lines))
(defun +scroll-other-window-down () (interactive) (scroll-other-window-down +scrolling-lines))
(defun +scroll-window () (interactive) (scroll-up +scrolling-lines))
(defun +scroll-window-down () (interactive) (scroll-down +scrolling-lines))
(bind-keys*
 ("C-M-v" . +scroll-other-window)
 ("M-<down>" . +scroll-other-window)

 ("C-M-S-v" . +scroll-other-window-down)
 ("M-<up>" . +scroll-other-window-down)

 ("C-v" . +scroll-window)
 ("M-v" . +scroll-window-down))


;; [tramp] Edit file remotely
(use-package tramp
  :config
  (setq tramp-default-method "rpc"
        tramp-backup-directory-alist backup-directory-alist
        remote-file-name-inhibit-cache 60))


(use-package tramp-rpc
  :straight (:type git
                   :host github
                   :repo "ArthurHeymans/emacs-tramp-rpc")
  :after tramp
  :init
  (setq tramp-rpc-deploy-local-cache-directory
        (no-littering-expand-var-file-name "tramp-rpc/"))
  (make-directory tramp-rpc-deploy-local-cache-directory t)
  :config
  (setq tramp-rpc-deploy-auto-deploy t
        tramp-rpc-deploy-git-build-policy 'release))


;; [minibuffer]
(use-package minibuffer
  :hook (after-init . minibuffer-electric-default-mode)
  :config
  (setq minibuffer-default-prompt-format " [%s]" ; shorten " (default %s)" => " [%s]"
        ;; One frame one minibuffer.
        minibuffer-follows-selected-frame nil))


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
(use-package exec-path-from-shell
  :straight t
  :unless noninteractive
  :init
  (setq exec-path-from-shell-shell-name "/etc/profiles/per-user/dragon/bin/fish"
        exec-path-from-shell-arguments nil
        exec-path-from-shell-variables
        '("PATH" "MANPATH" "PKG_CONFIG_PATH"
          "NIX_SSL_CERT_FILE" "NIX_PATH"
          "JAVA_HOME" "JAVA21_HOME" "JAVA26_HOME" "JDTLS_JAVA_HOME"))
  ;; External programs can be needed by mode hooks during startup, so import
  ;; the login-shell environment before the rest of the configuration loads.
  (exec-path-from-shell-initialize))


;; [backup walker] A utility to view Emacs backup files.
(use-package backup-walker
  :straight t)


;; [posframe]
(use-package posframe :straight t)

;; [project] Project manager
(use-package project
  :straight (:type built-in)
  :bind (:map project-prefix-map
              ("m" . magit-status))
  :config
  (setq project-switch-commands '((project-find-file "File")
                                  (project-find-regexp "Regexp")
                                  (project-switch-to-buffer "Buffer")
                                  (project-dired "Dired")
                                  (project-eshell "Eshell")
                                  (project-search "Search")
                                  (magit-status "Magit"))))

;; Prevent accidental touch.  Applies on every system, not only macOS.
(unbind-key "C-<wheel-down>")
(unbind-key "C-<wheel-up>")

;; [eshell] Emacs command shell
(use-package esh-mode
  :defines eshell-prompt-function
  :functions eshell/alias
  :hook ((eshell-mode . compilation-shell-minor-mode))
  :bind (("C-`" . +eshell-toggle)
         ("C-·" . +eshell-toggle)
         :map eshell-mode-map
         ("M-s" . consult-history))
  :config
  (setq
   ;; banner
   eshell-banner-message ""

   ;; scrolling
   eshell-scroll-to-bottom-on-input 'all
   eshell-scroll-to-bottom-on-output 'all

   ;; exit
   eshell-kill-processes-on-exit t
   eshell-hist-ignoredups t

   eshell-input-filter #'eshell-input-filter-initial-space

   ;; em-glob
   eshell-glob-case-insensitive t
   eshell-error-if-no-glob t

   ;; prefer eshell functions
   eshell-prefer-lisp-functions t

   ;; Visual commands require a proper terminal. Eshell can't handle that
   eshell-visual-commands '("top" "htop" "less" "more" "bat" "telnet")
   eshell-visual-subcommands '(("git" "help" "lg" "log" "diff" "show"))

   ;; Completion like bash
   eshell-cmpl-ignore-case t
   eshell-cmpl-cycle-completions nil

   ;; Aliases are defined below in Lisp.
   eshell-aliases-file nil)

  (defun +eshell-toggle (&optional arg)
    "Toggle a persistent Eshell popup window for the current project or directory.
If the popup is visible but unselected, select it.
If the popup is focused, kill it.
If no project is found, create a temporary Eshell instance in the current directory."
    (interactive "P")
    (require 'eshell)
    (let* ((project (project-current))
           (dir-name (directory-file-name default-directory))
           (root-name (if project
                          (file-name-nondirectory (directory-file-name (project-root project))) ;; Use project name
                        (file-name-nondirectory dir-name))) ;; Use current directory name if no project
           (popup-buffer-name (format "%s-popup: %s" (if arg "Ghostel" "Eshell") root-name))
           (win (get-buffer-window popup-buffer-name)))

      ;; If an argument is provided, you can add some custom behavior, like opening a GPT prompt.
      ;; If Eshell window exists, either focus or kill it.
      (if win
          (if (eq (selected-window) win)
              (ignore-errors (delete-window win)) ;; Close window if already focused
            (select-window win)) ;; Focus the Eshell window if it exists but not selected
        ;; If no Eshell window, create one.  `display-comint-buffer-action'
        ;; was removed in Emacs 31.  `eshell' passes `(category . comint)'
        ;; and asks for the same window; an alist entry is consulted first.
        ;; Append it so Popper's earlier rule still owns `Eshell-popup'.
        (let ((display-buffer-alist
               (append display-buffer-alist
                       '(((category . comint)
                          (display-buffer-at-bottom)
                          (inhibit-same-window . nil))))))
          (if arg
              (with-current-buffer (ghostel-project)
                ;; display current buffer
                (display-buffer (current-buffer)))
            ;; Open a eshell
            (let ((eshell-buffer-name popup-buffer-name))
              (with-current-buffer (eshell)
                (unless (string= dir-name (directory-file-name default-directory))
                  (eshell/cd dir-name)
                  (eshell-send-input))
                ;; Add a hook to close the window when Eshell exits
                (add-hook! eshell-exit-hook :local
                  (ignore-errors
                    (delete-window (get-buffer-window popup-buffer-name)))))))))))

  (add-hook! eshell-first-time-mode-hook
    (defun +eshell/define-alias ()
      "Define alias for eshell"
      (pcase-dolist (`(,name . ,command)
                     '((eshell-f . find-file)
                       (eshell-fo . find-file-other-window)
                       (eshell-d . dired)
                       (eshell-q . eshell/exit)
                       (eshell-vim . find-file)
                       (eshell-vi . find-file)))
        (defalias name command))
      (pcase-dolist (`(,name . ,definition)
                     '(("l" . "ls -lah $*")
                       ("ll" . "ls -laG $*")
                       ("rg" . "rg --color=always $*")
                       ("gst" . "git status $*")
                       ("ga" . "git add $*")
                       ("gc" . "git commit $*")
                       ("gp" . "git push $*")
                       ("gb" . "git branch $*")
                       ("gch" . "git checkout $*")
                       ("gcb" . "git checkout -b $*")))
        (eshell/alias name definition))))

  ;;; A bunch of eshell functions
  ;; [emacs, e, ec, ecc]
  (defun eshell/emacs (&rest args)
    "Open a file (ARGS) in Emacs."
    (if (null args)
        ;; If I just ran "emacs"
        (bury-buffer)
      ;; We have to expand the file names or else naming a directory in an
      ;; argument causes later arguments to be looked for in that directory,
      ;; not the starting directory
      (mapc #'find-file (mapcar #'expand-file-name (flatten-tree (reverse args))))))
  (defalias 'eshell/e #'eshell/emacs)
  (defalias 'eshell/ec #'eshell/emacs)

  ;; [ebc]
  (defun eshell/ebc (&rest args)
    "Compile a file (ARGS) in Emacs. Use `compile' to do background make."
    (if (eshell-interactive-output-p)
        (let ((compilation-process-setup-function
               (list 'lambda nil
                     (list 'setq 'process-environment
                           (list 'quote (eshell-copy-environment))))))
          (compile (eshell-flatten-and-stringify args))
          (pop-to-buffer next-error-last-buffer))
      (throw 'eshell-replace-command
             (let ((l (eshell-stringify-list (flatten-tree args))))
               (eshell-parse-command (car l) (cdr l))))))
  (put 'eshell/ebc 'eshell-no-numeric-conversions t)

  ;; [less, more]
  (defun eshell/less (&rest args)
    "Invoke `view-file' on a file (ARGS).
\"less +42 foo\" will go to line 42 in the buffer for foo."
    (while args
      (if (string-match "\\`\\+\\([0-9]+\\)\\'" (car args))
          (let* ((line (string-to-number (match-string 1 (pop args))))
                 (file (pop args)))
            (+eshell-view-file file)
            (forward-line line))
        (+eshell-view-file (pop args)))))
  (defalias 'eshell/more #'eshell/less)

  ;; [bat]
  (defun eshell/bat (file)
    "cat FILE with syntax highlight."
    (with-temp-buffer
      (insert-file-contents file)
      (let ((buffer-file-name file))
        (delay-mode-hooks (set-auto-mode) (font-lock-ensure)))
      (buffer-string)))

  ;; [bd]
  (defun eshell/bd ()
    "cd to parent directory with completions."
    (let ((dir default-directory)
          dirs)
      (while (not (string-empty-p dir))
        (push (file-name-directory dir) dirs)
        (setq dir (substring dir 0 -1)))
      (let ((dir (completing-read "Directory: " dirs nil t)))
        (eshell/cd dir))))


  ;; view file
  (defun +eshell-view-file (file)
    "View FILE.  A version of `view-file' which properly rets the eshell prompt."
    (interactive "fView file: ")
    (unless (file-exists-p file) (error "%s does not exist" file))
    (let ((buffer (find-file-noselect file)))
      (if (eq (get (buffer-local-value 'major-mode buffer) 'mode-class)
              'special)
          (progn
            (switch-to-buffer buffer)
            (message "Not using View mode because the major mode is special"))
        (let ((undo-window (list (window-buffer) (window-start)
                                 (+ (window-point)
                                    (length (funcall eshell-prompt-function))))))
          (switch-to-buffer buffer)
          (view-mode-enter (cons (selected-window) (cons nil undo-window))
                           'kill-buffer)))))

  ;; Sync buffer name
  (add-hook! (eshell-directory-change-hook eshell-mode-hook)
    (defun +eshell-sync-dir-buffer-name ()
      "Change eshell buffer name by directory change."
      (when (and (equal major-mode 'eshell-mode)
                 ;; avoid renaming buffer name like Eshell-popup: ...
                 (not (string-match-p "^Eshell-popup: " (buffer-name))))
        (rename-buffer (concat "Esh: " (abbreviate-file-name default-directory)) t)))))


;; [esh-syntax-highlighting] Fish-like syntax highlighting
(use-package eshell-syntax-highlighting
  :straight t
  :after eshell
  :hook (eshell-mode . eshell-syntax-highlighting-mode))


;; [eshell-z] `cd' to frequent directory in `eshell'
(use-package eshell-z
  :straight t
  :after eshell
  :commands (eshell/z))


(use-package esh-autosuggest-corfu
  :straight (:host github :repo "roife/esh-autosuggest-corfu")
  :hook (eshell-mode . esh-autosuggest-corfu-mode))


(use-package esh-help
  :straight t
  :preface
  (defun +eshell-setup-esh-help-eldoc ()
    "Use `esh-help' as the Eldoc backend in Eshell."
    (require 'esh-help)
    (setq-local eldoc-documentation-function #'esh-help-eldoc-command))
  :hook ((eshell-mode . +eshell-setup-esh-help-eldoc)
         (eshell-mode . eldoc-mode))
  :config
  (defadvice! +eshell-esh-help-eldoc-man-minibuffer-string-a (cmd)
    :override #'esh-help-eldoc-man-minibuffer-string
    (if-let* ((cache-result (gethash cmd esh-help-man-cache)))
        (unless (eql 'none cache-result)
          cache-result)
      (let ((str (split-string (esh-help-man-string cmd) "\n")))
        (if (equal (concat "No manual entry for " cmd) (car str))
            (ignore (puthash cmd 'none esh-help-man-cache))
          (puthash
           cmd (when-let* ((str (seq-drop-while (lambda (s) (not (string-match-p "^SYNOPSIS$" s))) str))
                           (str (nth 1 str)))
                 (substring str (string-match-p "[^\s\t]" str)))
           esh-help-man-cache))))))


;; [esh-tldr] Browse local tldr pages
(use-package esh-tldr
  :straight (:host github :repo "roife/esh-tldr")
  ;; `consult-esh-tldr' was removed; pages complete via `completing-read'.
  :commands (esh-tldr esh-tldr-dwim)
  :bind ("C-h t" . esh-tldr-dwim)
  :config
  (setq esh-tldr-use-tempel t))


(use-package eshell-did-you-mean
  :straight t
  :after esh-mode
  :init (eshell-did-you-mean-setup)
  ;; HACK: `pcomplete-completions' returns a function, but
  ;;   `eshell-did-you-mean--get-all-commands' unconditionally expects it to
  ;;   return a list of strings, causing wrong-type-arg errors in many cases.
  ;;   `all-completions' handles all these cases.
  (defadvice! +eshell--fix-eshell-did-you-mean-a (&rest _)
    :override #'eshell-did-you-mean--get-all-commands
    (unless eshell-did-you-mean--all-commands
      (setq eshell-did-you-mean--all-commands
            (all-completions "" (pcomplete-completions))))))


(use-package ghostel
  :straight t
  :preface
  (defun +ghostel-send-C-k-and-kill ()
    "Send `C-k' to ghostel.
Like normal Emacs `C-k'.  Kill to end of line and put content in kill-ring."
    (interactive)
    (kill-ring-save (point) (line-end-position))
    (ghostel-send-key "k" "ctrl"))

  :bind (("C-x m" . ghostel)
         :map ghostel-semi-char-mode-map
         ("C-g"  . keyboard-quit)
         ("C-k"  . +ghostel-send-C-k-and-kill)
         ;; I'm used to go up/down the shell history with M-n/p from eshell
         ;; Simulate this behavior in ghostel by sending C-p and C-n
         ("M-p" . (lambda () (interactive) (ghostel-send-key "p" "ctrl")))
         ("M-n" . (lambda () (interactive) (ghostel-send-key "n" "ctrl")))
         :map project-prefix-map
         ("m" . ghostel-project)
         ("M" . ghostel-project-list-buffers))
  :init
  (setq ghostel-module-directory
        (no-littering-expand-var-file-name "ghostel/")
        ghostel-module-auto-install 'download
        ghostel-enable-osc52 t
        ghostel-max-scrollback (* 50 1024 1024))
  (make-directory ghostel-module-directory t)

  :config
  (defadvice! +ghostel-project-popup-buffer-name (_orig root)
    :around 'ghostel--project-buffer-name
    "Name `ghostel-project' buffers as Popper popup buffers for ROOT."
    (let* ((project-name (file-name-nondirectory
                          (directory-file-name root)))
           (remote (file-remote-p root))
           (remote-suffix (when remote
                            (format "@%s" (string-trim remote "/" ":")))))
      (format "Ghostel-popup: %s%s" project-name (or remote-suffix ""))))

  (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)
  (add-to-list 'project-switch-commands '(ghostel-project-list-buffers "Ghostel buffers") t)
  (add-to-list 'ghostel-eval-cmds '("magit-status-setup-buffer" magit-status-setup-buffer)))


(use-package ghostel-eshell
  :hook (eshell-load . ghostel-eshell-visual-command-mode))
;; warp/truncation indicator in tty
(set-display-table-slot standard-display-table
                        'wrap
                        (make-glyph-code ?↩ 'shadow))

(set-display-table-slot standard-display-table
                        'truncation
                        (make-glyph-code ?… 'shadow))
;; [Kitty Keyboard Protocol] Implements support for Kitty's "keyboard protocol",
;; which allows the terminal to send key events to Emacs.
(use-package kkp
  :straight t
  :hook (tty-setup . global-kkp-mode)
  :init
  ;; Read when the mode turns on, so this has to precede it. KKP sends
  ;; C-g as CSI-u; without this, a blocking call-process cannot be quit.
  (setq kkp-restore-legacy-keys-around-subprocesses t))
;; [xterm]
(use-package term/xterm
  :hook (tty-setup . xterm-mouse-mode)
  :init
  (setq xterm-extra-capabilities '(modifyOtherKeys reportBackground
                                                   getSelection setSelection)
        xterm-set-window-title t)

  (defun +xterm-report-background ()
    "Query the terminal background color and reload the matching theme."
    (interactive)
    (unless (display-graphic-p)
      (require 'term/xterm)
      (xterm--query "\e]11;?\e\\"
                    '(("\e]11;" . xterm--report-background-handler))
                    t)
      (let ((bg-color (terminal-parameter nil 'xterm--background-color)))
        (when bg-color
          (apply #'xterm--set-background-mode bg-color)))
      (+load-theme)
      (message "Reported terminal background as %s"
               (terminal-parameter nil 'background-mode)))))

;; [which-key] Discover key bindings as you type
(use-package which-key
  :hook (after-init . which-key-mode)
  :config
  (setq which-key-separator "  "
        which-key-prefix-prefix "... "
        which-key-max-display-columns 3
        which-key-idle-delay 1.5
        which-key-idle-secondary-delay 0.25
        which-key-add-column-padding 1
        which-key-max-description-length 40))

;; [tmr] Set timers
(use-package tmr
  :straight t
  :bind ("C-c T" . tmr-prefix-map)
  :config
  (setopt tmr-notification-urgency 'normal)
  (setq tmr-description-list 'tmr-description-history))

;; [pass] Password store interface
(use-package password-store
  :straight t
  :bind ("C-c k" . password-store-copy)
  :config
  (setq password-store-time-before-clipboard-restore 30))

(use-package pass
  :straight t)

(provide 'init-core)
