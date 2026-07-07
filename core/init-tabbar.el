;; -*- lexical-binding: t; -*-

;; [tab-bar] Tab bar
(use-package tab-bar
  ;; Turn on tab-bar-mode in early-init to speed-up
  ;; :hook (window-setup . tab-bar-mode)
  ;; :bind (:map tab-bar-mode-map
  ;;             ("M-w" . tab-close)
  ;;             ("M-t" . tab-new)
  ;;             ("M-o" . other-window))
  :config
  (setq tab-bar-separator ""
        tab-bar-new-tab-choice "*scratch*"
        tab-bar-tab-name-truncated-max 20
        tab-bar-auto-width nil
        tab-bar-close-button-show nil
        tab-bar-tab-hints t)

  (customize-set-variable 'tab-bar-select-tab-modifiers '(meta))

  ;; truncate for [tab name] and add count
  (setq tab-bar-tab-name-format-functions
        '(tab-bar-tab-name-format-hints
          tab-bar-tab-name-format-truncated
          (lambda (name &rest _) (concat " " name " "))
          tab-bar-tab-name-format-face))

  (setq tab-bar-format '(tab-bar-format-tabs))

  ;; WORKAROUND: fresh tab-bar for daemon
  (add-hook! (server-after-make-frame-hook window-setup-hook) :call-immediately
    (defun +refresh-tab-bar (&rest _)
      (tab-bar--update-tab-bar-lines)
      (force-mode-line-update)))
  )
