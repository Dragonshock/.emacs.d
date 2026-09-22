;;; -*- lexical-binding: t -*-

;; macOS steals Control-Command-D (Look Up).
(when (featurep 'ns)
  (unbind-key "C-s-d"))

;; [emt] CJK word motion via macOS NLP tokenizer (needs a native .dylib).
(use-package emt
  :straight (:host github :repo "roife/emt"
                   :files ("*.el" "module/*" "module"))
  :commands (emt-mode emt-download-module emt-ensure
                      emt-forward-word emt-backward-word)
  :init
  (setq emt-lib-path
        (concat (no-littering-expand-var-file-name "modules/libEMT")
                module-file-suffix))
  (defun +emt-enable-or-install ()
    "Enable `emt-mode' without interactive prompts during startup."
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
