;;; -*- lexical-binding: t -*-

;; (setq mac-option-modifier 'meta
;;       mac-command-modifier 'super
;;       mac-right-command-modifier 'left)

;; [osx-dictionary] macOS native dictionary app
(use-package osx-dictionary
  :straight t
  :bind (("C-c d i" . osx-dictionary-search-input)
         ("C-c d d" . osx-dictionary-search-pointer)))

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
  (defun +emt-enable-or-install ()
    "Enable `emt-mode' without interactive prompts during startup.

If the native module is missing, download it non-interactively.  On
failure, leave emt disabled and print a recovery message."
    (require 'emt)
    (condition-case err
        (progn
          (unless (file-exists-p emt-lib-path)
            (message "emt: native module missing; downloading to %s ..." emt-lib-path)
            (emt-download-module))
          (unless emt-mode
            (emt-mode 1)))
      (error
       (message "emt: skipped (%s). Fix later with M-x emt-download-module"
                (error-message-string err)))))
  :hook (window-setup . +emt-enable-or-install))

(add-hook! ns-system-appearance-change-functions
  (defun +mac-auto-change-theme-with-system (&rest _)
    (+load-theme)))

;; Prevent accidental touch
(unbind-key "C-<wheel-down>")
(unbind-key "C-<wheel-up>")
