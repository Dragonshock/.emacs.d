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

(unbind-key "s-,")
(bind-keys ("s-a" . mark-whole-buffer)
           ("s-x" . kill-region)
           ("s-s" . save-buffer)
           ("s-v" . yank)
           ("s-c" . copy-region-as-kill)
           ("s-z" . undo)
           ("s-Z" . undo-redo)
           ("s-f" . isearch-forward)
           ("s-w" . tab-close)
           ("s-t" . tab-new)
           ("s-o" . other-window))
