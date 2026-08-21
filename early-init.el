;;; -*- lexical-binding: t -*-
;;; Mainly for speeding up startup time

;; Defer GC during startup, then restore sane runtime defaults later.
(defvar +gc-cons-threshold (* 32 1024 1024)
  "Default `gc-cons-threshold' after startup.")
(defvar +gc-cons-percentage 0.2
  "Default `gc-cons-percentage' after startup.")

(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 1.0)

(defun +restore-gc-threshold-h ()
  "Restore GC settings after startup."
  (setq gc-cons-threshold +gc-cons-threshold
        gc-cons-percentage +gc-cons-percentage))

(add-hook 'emacs-startup-hook #'+restore-gc-threshold-h 100)

;; Keep native compilation artifacts under no-littering's `var/' directory.
;; (native-comp-jit-compilation defaults to t on Emacs 31; no need to setq.)
(when (and (fboundp 'startup-redirect-eln-cache)
           (fboundp 'native-comp-available-p)
           (native-comp-available-p))
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name "var/eln-cache/" user-emacs-directory))))

;; Keep early startup quiet unless we're debugging init.
;; Match upstream (roife): only report native-comp warnings when debugging
;; (`emacs --debug-init` sets init-file-debug). Default nil suppresses the
;; common "function is not known to be defined" popups from third-party
;; packages (emt / easy-kill / reader, etc.). Keep eln-cache redirect above.
(setq ad-redefinition-action 'accept
      jka-compr-verbose init-file-debug
      native-comp-async-report-warnings-errors init-file-debug
      native-comp-warning-on-missing-source init-file-debug
      native-comp-async-on-battery-power nil
      warning-suppress-types '((defvaralias) (lexical-binding))
      warning-inhibit-types '((files missing-lexbind-cookie)))

;; Prefer newer .el over stale .elc in GUI too.  Interactive used to
;; keep load-prefer-newer nil, so Dock Emacs loaded outdated core/*.elc
;; and straight/build/*.elc (Emacs 31 then reports parse EOF as
;; #<killed buffer>, bug#80063).
(setq load-prefer-newer t)

;; Inhibit resizing frame
(setq frame-inhibit-implied-resize t)

;; Inhibit startup screen & message.
;; Note: (setq inhibit-startup-echo-area-message t) is a no-op; Emacs only
;; honors a login-name string via Customize or user-init-file. The advice
;; below is what actually suppresses the echo-area message.
(setq inhibit-startup-screen t
      inhibit-startup-buffer-menu t
      inhibit-x-resources t
      inhibit-default-init t
      initial-scratch-message nil
      initial-major-mode 'fundamental-mode)
(advice-add #'display-startup-echo-area-message :override #'ignore)
(advice-add #'display-startup-screen :override #'ignore)

;; Suppress flashing at startup
(setq-default inhibit-redisplay t
              inhibit-message t)
(add-hook 'window-setup-hook
          (lambda ()
            (setq-default inhibit-redisplay nil
                          inhibit-message nil)
            (unless (daemonp)
              (redraw-frame))))

;; Inhibit package.el initialization
(setq package-enable-at-startup nil)

;; Faster to disable these here (before initialized)
(push '(tab-bar-lines . 1) default-frame-alist)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(internal-border-width . 0) default-frame-alist)
;; Default frame: 120x50, centered on screen.  Float `left'/`top' in
;; [0.0, 1.0] position the frame proportionally inside the workarea
;; (0.5 = centered); verified on the NS port.
(push '(width . 120) default-frame-alist)
(push '(height . 50) default-frame-alist)
(push '(left . 0.5) default-frame-alist)
(push '(top . 0.5) default-frame-alist)
;; (push '(undecorated-round . t) default-frame-alist)
(when (featurep 'ns)
  (push '(ns-transparent-titlebar . t) default-frame-alist))
                                        ; Set these to nil so users don't have to toggle the modes twice to reactivate.
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil
      tab-bar-mode t)

;; Avoid toolbar setup work during startup. It is unnecessary while the toolbar is
;; disabled; remove the override after init so `tool-bar-mode' can rebuild the map.
(when (fboundp 'tool-bar-setup)
  (advice-add #'tool-bar-setup :override #'ignore)
  (add-hook 'emacs-startup-hook
            (lambda ()
              (advice-remove #'tool-bar-setup #'ignore))
            100))

;; Case-insensitive pass over `auto-mode-alist' is time wasted.
(setq auto-mode-case-fold nil)

;; Avoid processing command-line option tables irrelevant to this frame type.
(unless (eq system-type 'darwin)
  (setq command-line-ns-option-alist nil))
(unless (memq initial-window-system '(x pgtk))
  (setq command-line-x-option-alist nil))

;; `setopt' can load custom dependencies early for type checks. Inhibit that
;; only during init; remove the advice at startup so later setopt still runs
;; custom-load-symbol / :set (treesit remaps, timers, etc.).
(when (fboundp 'setopt--set)
  (define-advice setopt--set (:around (fn &rest args) inhibit-load-symbol -90)
    (let ((custom-load-recursion t))
      (apply fn args)))
  (add-hook 'emacs-startup-hook
            (lambda ()
              (advice-remove 'setopt--set #'setopt--set@inhibit-load-symbol))
            100))

;; `file-name-handler-alist' is consulted on each call to `require', `load', or
;; various file/io functions. Clear it for startup I/O (keep jka-compr so
;; compressed Lisp can still load), then merge back anything registered during init.
(unless (or (daemonp) noninteractive init-file-debug)
  (let ((old-value (default-toplevel-value 'file-name-handler-alist)))
    (put 'file-name-handler-alist 'initial-value (copy-sequence old-value))
    ;; Actually disable handlers for the bulk of init (was a silent no-op before).
    (set-default-toplevel-value
     'file-name-handler-alist
     (let ((jka (rassq 'jka-compr-handler old-value)))
       (if jka (list jka) nil)))
    (define-advice command-line-1 (:around (fn args-left) restore-file-name-handlers)
      (let ((file-name-handler-alist
             (if args-left (copy-sequence old-value) file-name-handler-alist)))
        (funcall fn args-left)))
    (add-hook 'emacs-startup-hook
              (lambda ()
                "Recover file name handlers."
                (set-default-toplevel-value
                 'file-name-handler-alist
                 (delete-dups
                  (append (default-toplevel-value 'file-name-handler-alist)
                          old-value))))
              101)))

;; Optimize load-suffixes for startup (prefer bytecode). Do not clear
;; load-file-rep-suffixes: stock/jka-compr needs ("" ".gz") so load and
;; locate-library can open compressed Lisp (foo.el.gz) after init.
(setq load-suffixes '(".elc" ".el"))

(defun +restore-load-suffixes-h ()
  "Restore dynamic module suffixes before loading the init file."
  (setq load-suffixes `(".elc" ".el"
                        ,@(when module-file-suffix (list module-file-suffix)))))

(add-hook 'before-init-hook #'+restore-load-suffixes-h 100)

;; Note: do not advice `load-file' for silence.  Emacs 31 loads site-start
;; before early-init via (load site-run-file t t), and early-init/init also
;; use `load' with nomessage — a late load-file override never covers them.
