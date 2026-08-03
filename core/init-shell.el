;;; -*- lexical-binding: t -*-

;; [eshell] Emacs command shell
(use-package esh-mode
  :defines eshell-prompt-function
  :functions eshell/alias
  :hook ((eshell-mode . compilation-shell-minor-mode))
  :bind (("C-`" . +eshell-toggle)
         ("C-·" . +eshell-toggle))
  :config
  ;; Emacs 31 binds M-r on `eshell-hist-mode-map' (minor); major-map binding is shadowed.
  (with-eval-after-load 'em-hist
    (keymap-set eshell-hist-mode-map "M-r" #'consult-history))
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
   )


  (defun +ghostel-toggle-project ()
    "Toggle the current project's Ghostel terminal window.
Uses stock `ghostel-project' buffer identity (no Ghostel-popup rename)."
    (require 'ghostel)
    (let* ((root (project-root (project-current t)))
           (identity (ghostel--project-buffer-name root))
           (buf (ghostel--find-buffer-by-identity identity))
           (win (and buf (get-buffer-window buf))))
      (cond
       ((and win (eq (selected-window) win))
        (ignore-errors (delete-window win)))
       (win (select-window win))
       (t (ghostel-project)))))

  (defun +eshell-toggle (&optional arg)
    "Toggle a persistent Eshell popup, or with ARG a project Ghostel terminal.
If the target window is visible but unselected, select it.
If it is focused, delete the window.
Plain call: Eshell popup for the current project/directory.
Prefix ARG: `ghostel-project' (stock buffer name / display, dakra-aligned)."
    (interactive "P")
    (require 'eshell)
    (require 'project)
    (if arg
        (+ghostel-toggle-project)
      (let* ((project (project-current))
             (dir-name (directory-file-name default-directory))
             (root-name (if project
                            (file-name-nondirectory
                             (directory-file-name (project-root project)))
                          (file-name-nondirectory dir-name)))
             (popup-buffer-name (format "Eshell-popup: %s" root-name))
             (win (get-buffer-window popup-buffer-name)))
        (if win
            (if (eq (selected-window) win)
                (ignore-errors (delete-window win))
              (select-window win))
          ;; `display-comint-buffer-action' was removed in Emacs 31 (obsolete
          ;; since 30.1).  Match the `(category . comint)' action eshell uses.
          (let ((display-buffer-alist
                 (cons '((category . comint)
                         (display-buffer-at-bottom)
                         (inhibit-same-window . nil))
                       display-buffer-alist))
                (eshell-buffer-name popup-buffer-name))
            (with-current-buffer (eshell)
              (unless (string= dir-name (directory-file-name default-directory))
                (eshell/cd dir-name)
                (eshell-send-input))
              (add-hook 'eshell-exit-hook
                        (lambda ()
                          (ignore-errors
                            (delete-window (get-buffer-window popup-buffer-name))))
                        nil t)))))))

  (defun +eshell/define-alias ()
    "Define alias for eshell.
Eshell looks up `eshell/NAME' (slash), not `eshell-NAME' (hyphen)."
    ;; Lisp-backed commands (eshell-find-alias-function → eshell/NAME)
    (defalias 'eshell/f #'find-file)
    (defalias 'eshell/fo #'find-file-other-window)
    (defalias 'eshell/d #'dired)
    (defalias 'eshell/q #'eshell/exit)
    (defalias 'eshell/vim #'find-file)
    (defalias 'eshell/vi #'find-file)
    ;; String aliases
    (eshell/alias "l" "ls -lah $*")
    (eshell/alias "ll" "ls -laG $*")
    (eshell/alias "rg" "rg --color=always $*")
    ;; Git
    (eshell/alias "git" "git $*")
    (eshell/alias "gst" "git status $*")
    (eshell/alias "ga" "git add $*")
    (eshell/alias "gc" "git commit $*")
    (eshell/alias "gp" "git push $*")
    (eshell/alias "gb" "git branch $*")
    (eshell/alias "gch" "git checkout $*")
    (eshell/alias "gcb" "git checkout -b $*")
    )
  (add-hook 'eshell-first-time-mode-hook #'+eshell/define-alias)
  ;; Don't auto-write our aliases! Let us manage our own `eshell-aliases-file' via elisp
  (advice-add #'eshell-write-aliases-list :override #'ignore)

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


  ;; view file — quit-restore is Emacs 31's 4-list
  ;; (TYPE QUAD SELWIN BUFFER).  Reuse + different buffer → TYPE `other';
  ;; QUAD size is height if vertically combined else width (window.el).
  ;; Exit action mirrors stock `view-file': only kill if we opened a new
  ;; buffer, and then only if unmodified (never raw `kill-buffer' on a
  ;; file-visiting buffer — that can discard unsaved edits on View-quit).
  (defun +eshell-view-file (file)
    "View FILE.  A version of `view-file' which properly rets the eshell prompt."
    (interactive "fView file: ")
    (unless (file-exists-p file) (error "%s does not exist" file))
    (let ((had-a-buf (get-file-buffer file))
          (buffer (find-file-noselect file)))
      (if (eq (get (buffer-local-value 'major-mode buffer) 'mode-class)
              'special)
          (progn
            (switch-to-buffer buffer)
            (message "Not using View mode because the major mode is special"))
        (let* ((return-buffer (window-buffer))
               (return-start (window-start))
               (return-point (+ (window-point)
                                (length (funcall eshell-prompt-function))))
               (return-size (if (window-combined-p)
                                (window-total-height)
                              (window-total-width))))
          (switch-to-buffer buffer)
          (view-mode-enter
           (list 'other
                 (list return-buffer return-start return-point return-size)
                 (selected-window)
                 buffer)
           (and (not had-a-buf) #'kill-buffer-if-not-modified))))))

  ;; Sync buffer name
  (add-hook! (eshell-directory-change-hook eshell-mode-hook)
    (defun +eshell-sync-dir-buffer-name ()
      "Change eshell buffer name by directory change."
      (when (and (equal major-mode 'eshell-mode)
                 ;; avoid renaming buffer name like Eshell-popup: ...
                 (not (string-match-p "^Eshell-popup: " (buffer-name))))
        (rename-buffer (concat "Esh: " (abbreviate-file-name default-directory)) t))))
  )


;; [esh-syntax-highlighting] Fish-like syntax highlighting
(use-package eshell-syntax-highlighting
  :straight t
  :after eshell
  :hook (eshell-mode . eshell-syntax-highlighting-mode))


;; [eshell-z] `cd' to frequent directory in `eshell'
;; Load on eshell-mode so frecent visits are recorded before the first `z'.
(use-package eshell-z
  :straight t
  :after eshell
  :hook (eshell-mode . (lambda () (require 'eshell-z)))
  :commands (eshell/z))


(use-package esh-autosuggest-corfu
  :straight (:host github :repo "roife/esh-autosuggest-corfu")
  :hook (eshell-mode . esh-autosuggest-corfu-mode))


(use-package esh-help
  :straight t
  :preface
  (defun +esh-help-eldoc-backend (callback &rest _)
    "Eldoc backend wrapping `esh-help-eldoc-command' (modern multi-backend API)."
    (when-let* ((doc (esh-help-eldoc-command)))
      (funcall callback doc)))
  (defun +eshell-setup-esh-help-eldoc ()
    "Register `esh-help' on `eldoc-documentation-functions' in Eshell."
    (require 'esh-help)
    ;; Do not set obsolete `eldoc-documentation-function' to a string-returning
    ;; command; that skips the composable `eldoc-documentation-functions' hook.
    (add-hook 'eldoc-documentation-functions #'+esh-help-eldoc-backend nil t))
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
  :commands (esh-tldr esh-tldr-dwim consult-esh-tldr)
  :bind ("C-h t" . esh-tldr-dwim)
  :config
  (setq esh-tldr-use-tempel t))



;; eshell-did-you-mean 0.2 is unmaintained and assumes (pcomplete-completions)
;; is a plain string list, then mapcar's it for edit-distance.  Emacs 31 Eshell
;; bare-command completion returns a programmed completion table (function /
;; completion-table-dynamic via eshell--complete-commands-list).  Materialize
;; with all-completions first.  MERGE LOCK: keep vs roife/upstream; stock 0.2
;; breaks the eshell preoutput filter on Emacs 31.
(use-package eshell-did-you-mean
  :straight t
  :after esh-mode
  :init
  (defadvice! +eshell--fix-eshell-did-you-mean-a (&rest _)
    :override #'eshell-did-you-mean--get-all-commands
    (unless eshell-did-you-mean--all-commands
      (setq eshell-did-you-mean--all-commands
            (all-completions "" (pcomplete-completions)))))
  (eshell-did-you-mean-setup))


;; Ghostel lives in `init-ghostel.el` (loaded earlier). Eshell prefix still
;; calls `ghostel-project' (still defined by ghostel; project-scoped terminal).
