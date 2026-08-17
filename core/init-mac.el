;;; -*- lexical-binding: t -*-

;; (setq mac-option-modifier 'meta
;;       mac-command-modifier 'super
;;       mac-right-command-modifier 'left)

;; [osx-dictionary] The Little Dict, not Oxford / LDOCE5.
;; Result goes in *osx-dictionary* (`osx-dictionary-mode').
;; Stock osx-dictionary-cli uses DCSGetDefaultDictionary (Oxford) — do not call it.
;; Runtime bundle is ~/Library/Dictionaries/TLD.dictionary, not the
;; ~/Desktop/The Little Dict source repo.
(defconst +tld-bundle-path
  (expand-file-name "~/Library/Dictionaries/TLD.dictionary"))

(defconst +tld-lookup-source
  (expand-file-name "scripts/tld-lookup.m" user-emacs-directory))

(defun +tld-lookup-program ()
  (no-littering-expand-var-file-name "modules/tld-lookup"))

(defun +tld-lookup-ensure ()
  "Return the tld-lookup binary, compiling it if the source is newer.

Does not run at init.  First `C-c d d' pays for clang (~1s)."
  (let ((dest (+tld-lookup-program))
        (src +tld-lookup-source))
    (unless (file-readable-p src)
      (user-error "tld-lookup source missing: %s" src))
    (when (or (not (file-executable-p dest))
              (file-newer-than-file-p src dest))
      (unless (executable-find "clang")
        (user-error "clang not found; cannot build tld-lookup"))
      (make-directory (file-name-directory dest) t)
      (with-temp-buffer
        (let ((status (call-process
                       "clang" nil t nil
                       "-O2" "-fobjc-arc"
                       "-framework" "Foundation"
                       "-framework" "AppKit"
                       "-framework" "CoreServices"
                       "-framework" "Carbon"
                       "-o" dest src)))
          (unless (eq status 0)
            (user-error "tld-lookup compile failed:\n%s" (buffer-string))))))
    dest))

(defun +tld-lookup-text (word)
  "Plain-text The Little Dict definition of WORD."
  (let ((prog (+tld-lookup-ensure)))
    (unless (file-exists-p +tld-bundle-path)
      (user-error
       "The Little Dict not installed at %s — see ~/Desktop/The Little Dict/README.md"
       +tld-bundle-path))
    (with-temp-buffer
      (let ((status (call-process prog nil t nil "--text" "--" word)))
        (let ((out (buffer-string)))
          (unless (eq status 0)
            (user-error "tld-lookup failed (%s): %s" status (string-trim out)))
          out)))))

(defun +osx-dictionary-view-text (word text)
  "Show TEXT in `*osx-dictionary*' as WORD.

Replaces `osx-dictionary--search' for this call only, so the stock
Oxford CLI is never invoked."
  (require 'cl-lib)
  (require 'osx-dictionary)
  (cl-letf (((symbol-function 'osx-dictionary--search)
             (lambda (_word) text)))
    (osx-dictionary--view-result word)))

(defun +osx-dictionary-search-pointer ()
  "Look up the word at point in The Little Dict; show it in `*osx-dictionary*'."
  (interactive)
  (let ((word (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (or (thing-at-point 'word t)
                    (user-error "Nothing to look up")))))
    (+osx-dictionary-view-text word (+tld-lookup-text word))))

(defun +osx-dictionary-search-input ()
  "Prompt for a word, look it up in The Little Dict, show it in `*osx-dictionary*'."
  (interactive)
  (let* ((default (if (use-region-p)
                      (buffer-substring-no-properties (region-beginning) (region-end))
                    (thing-at-point 'word t)))
         (word (read-string (if default (format "Word (%s): " default) "Word: ")
                            nil nil default)))
    (when (string-blank-p word)
      (user-error "Nothing to look up"))
    (+osx-dictionary-view-text word (+tld-lookup-text word))))

(use-package osx-dictionary
  :straight t
  ;; `C-c d i' now belongs to `consult-imenu' (upstream), so search-input
  ;; moved to `C-c d s'.  macOS steals Control-Command-D (Look Up) before
  ;; Emacs sees it, so the second binding is `C-c d l', not `C-s-d'.
  ;; Do not bind `s-d' (stock isearch-repeat-backward).
  :bind (("C-c d s" . +osx-dictionary-search-input)
         ("C-c d d" . +osx-dictionary-search-pointer)
         ("C-c d l" . +osx-dictionary-search-pointer)))

;; Drop the dead Control-Command-D binding (macOS Look Up eats the event).
(when (featurep 'ns)
  (unbind-key "C-s-d"))

;; [emt] CJK word motion via macOS NLP tokenizer (needs a native .dylib).
;; Do NOT enable on after-init: emt-mode -> emt-ensure may call yes-or-no-p
;; while early-init still has inhibit-redisplay/inhibit-message, so the frame
;; looks frozen ("can't open"). Install the module without prompts, and only
;; after window-setup when the UI is visible.
(use-package emt
  :straight (:host github :repo "roife/emt"
                   :files ("*.el" "module/*" "module"))
  :commands (emt-mode emt-download-module emt-ensure
                      emt-forward-word emt-backward-word)
  :init
  ;; Keep dylib under no-littering `var/' (upstream path policy).
  (setq emt-lib-path
        (concat (no-littering-expand-var-file-name "modules/libEMT")
                module-file-suffix))
  (defun +emt-enable-or-install ()
    "Enable `emt-mode' without interactive prompts during startup.

If the native module is missing, do NOT auto-download (no integrity pin
on the remote artifact).  Leave a recovery message for interactive install.

Do not hook `after-init': `emt-mode' -> `emt-ensure' may call
`yes-or-no-p' while early-init still has inhibit-redisplay/message."
    (require 'emt)
    (condition-case err
        (if (file-exists-p emt-lib-path)
            (unless emt-mode
              (emt-mode 1))
          (message "emt: native module missing at %s — run M-x emt-download-module when ready (no auto-download)"
                   emt-lib-path))
      (error
       (message "emt: skipped (%s). Fix later with M-x emt-download-module"
                (error-message-string err)))))
  :hook (window-setup . +emt-enable-or-install))

;; emacs-plus system-appearance patch.  Re-detect via +load-theme (upstream).
(add-hook! ns-system-appearance-change-functions
  (defun +mac-auto-change-theme-with-system (&rest _)
    (+load-theme)))

;; Prevent accidental touch
(unbind-key "C-<wheel-down>")
(unbind-key "C-<wheel-up>")

(global-set-key (kbd "s-a") #'mark-whole-buffer)
(global-set-key (kbd "s-x") #'kill-region)
(global-set-key (kbd "s-s") #'save-buffer)
(global-set-key (kbd "s-v") #'yank)
(global-set-key (kbd "s-c") #'copy-region-as-kill)
(global-set-key (kbd "s-z") #'undo)
(global-set-key (kbd "s-Z") #'undo-redo)
(global-set-key (kbd "s-f") #'isearch-forward)
(global-set-key (kbd "s-w") #'tab-close)
(global-set-key (kbd "s-t") #'tab-new)
(global-set-key (kbd "s-o") #'other-window)
(global-set-key (kbd "s-,") nil)
