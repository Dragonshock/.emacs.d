;;; -*- lexical-binding: t -*-

;; Nix Emacs does not update `toolkit-theme' on macOS.  `+load-theme'
;; follows `+system-appearance', so publish that from AppleInterfaceStyle.
(defvar +mac-appearance-timer nil
  "Timer that rechecks the macOS appearance.")

(defun +mac-read-system-appearance ()
  "Return `dark' or `light' from AppleInterfaceStyle."
  (if (with-temp-buffer
        (when (eq 0 (call-process "defaults" nil t nil
                                  "read" "-g" "AppleInterfaceStyle"))
          (goto-char (point-min))
          (search-forward "Dark" nil t)))
      'dark
    'light))

(defun +mac-sync-system-appearance ()
  "Update `+system-appearance' when the macOS appearance changes."
  (let ((appearance (+mac-read-system-appearance)))
    (unless (eq appearance +system-appearance)
      (+system-appearance-changed appearance))))

(+mac-sync-system-appearance)
(setq +mac-appearance-timer
      (run-with-timer 2 2 #'+mac-sync-system-appearance))

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
