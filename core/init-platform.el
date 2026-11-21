;;; -*- lexical-binding: t -*-
(when (eq system-type 'gnu/linux)
  ;; Follow KDE, GNOME, and other desktops exposing the XDG Settings portal.
  (defvar +linux-appearance-signal nil
    "D-Bus registration for desktop appearance changes.")

  (defun +linux-appearance-changed (namespace key value)
    "Handle a Settings portal change to NAMESPACE, KEY, and VALUE."
    (when (and (equal namespace "org.freedesktop.appearance")
               (equal key "color-scheme"))
      ;; Read wraps the value twice; SettingChanged wraps it once.
      (while (consp value)
        (setq value (car value)))
      ;; Keep the existing dark default when the desktop has no preference.
      (+system-appearance-changed (if (eq value 2) 'light 'dark))))

  (add-hook! 'after-make-frame-functions :call-immediately
    (defun +linux-setup-appearance (&optional _frame)
      "Subscribe to desktop appearance changes and read the current setting."
      (when (and (require 'dbus nil t) (fboundp 'dbus-register-signal))
        ;; Headless sessions and builds without a session bus still start normally.
        ;; Retry on frame creation, which also refreshes the daemon's initial theme.
        (condition-case nil
            (progn
              (unless +linux-appearance-signal
                (setq +linux-appearance-signal
                      (dbus-register-signal
                       :session "org.freedesktop.portal.Desktop"
                       "/org/freedesktop/portal/desktop"
                       "org.freedesktop.portal.Settings" "SettingChanged"
                       #'+linux-appearance-changed)))
              (+linux-appearance-changed
               "org.freedesktop.appearance" "color-scheme"
               (dbus-call-method
                :session "org.freedesktop.portal.Desktop"
                "/org/freedesktop/portal/desktop"
                "org.freedesktop.portal.Settings" "Read" :timeout 1000
                "org.freedesktop.appearance" "color-scheme")))
          (dbus-error nil))))))

(when (eq system-type 'darwin)
  ;; Nix Emacs does not update `toolkit-theme' on macOS.  `+load-theme'
  ;; follows `+system-appearance', so publish that from AppleInterfaceStyle.
  (defvar +mac-appearance-timer nil
    "Timer that rechecks the macOS appearance.")

  (defun +mac-read-system-appearance ()
    "Return `dark' or `light' from AppleInterfaceStyle."
    ;; `call-process' inside `with-temp-buffer' signals file-missing
    ;; ("Setting current directory") when `default-directory' points at
    ;; a deleted directory, which made the sync timer below error
    ;; every 2 seconds.  `with-temp-buffer' inherits this binding.
    (let ((default-directory
            (if (file-directory-p default-directory)
                default-directory
              "/")))
      (if (with-temp-buffer
            (when (eq 0 (call-process "defaults" nil t nil
                                      "read" "-g" "AppleInterfaceStyle"))
              (goto-char (point-min))
              (search-forward "Dark" nil t)))
          'dark
        'light)))

  (defun +mac-sync-system-appearance ()
    "Update `+system-appearance' when the macOS appearance changes."
    (let ((appearance (+mac-read-system-appearance)))
      (unless (eq appearance +system-appearance)
        (+system-appearance-changed appearance))))

  (+mac-sync-system-appearance)
  (setq +mac-appearance-timer
        (run-with-timer 2 2 #'+mac-sync-system-appearance))


  ;; [Modifier keys] Command as Meta, Option as Super
  ;; (setq mac-command-modifier 'meta
  ;;       mac-option-modifier 'super)


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
             ("s-o" . other-window)
             ("s-SPC" . toggle-input-method)))

(provide 'init-platform)
