;;; -*- lexical-binding: t -*-

;;; face
;; Popper's mode-line indicator still inherits this face.
(defface +mode-line-meta-face
  '((t (:inherit (font-lock-function-name-face bold))))
  "The face for the popper mode-line indicator."
  :group 'faces)

(defun +mode-line-box-match-background (&rest _)
  "Color each mode-line box with that face's own background.
Ashen draws the box in the foreground color.  Matching the background
keeps the box without a contrasting outline.  `:overline' is cleared
so an earlier top-only line does not remain."
  (dolist (face '(mode-line mode-line-inactive))
    (let ((background (face-background face nil 'default)))
      (when (and (stringp background) (not (string-empty-p background)))
        (set-face-attribute face nil
                            :overline nil
                            :box (list :line-width 1 :color background))))))

(defun +tab-bar-selected-underline-off (&rest _)
  "Remove the underline under the selected tab-bar tab.
Ashen uses that underline as the current-tab mark.  `tab-line' is
left unchanged."
  (set-face-attribute 'tab-bar-tab nil :underline nil))

(add-hook 'enable-theme-functions #'+mode-line-box-match-background)
(add-hook 'after-init-hook #'+mode-line-box-match-background)
(add-hook 'enable-theme-functions #'+tab-bar-selected-underline-off)
(add-hook 'after-init-hook #'+tab-bar-selected-underline-off)

(setq-default header-line-format nil)

;;; Header Line
;; [breadcrumb] Add breadcrumb navigation in header-line
(use-package breadcrumb
  :straight (:host github :repo "joaotavora/breadcrumb" :files ("*.el"))
  :custom-face
  (breadcrumb-project-base-face ((t (:inherit breadcrumb-project-crumbs-face :bold t))))
  (breadcrumb-project-leaf-face ((t (:inherit font-lock-function-name-face :bold t))))
  (breadcrumb-imenu-leaf-face ((t (:inherit font-lock-function-name-face :foreground unspecified))))
  :config
  ;; The short prefix in breadcrumb.el expands to `breadcrumb-' when that
  ;; file is read, so the names below are the ones that exist afterwards.
  (setq breadcrumb-imenu-crumb-separator " ⋅ "
        breadcrumb-project-max-length 0.5
        breadcrumb-imenu-max-length 0.45
        breadcrumb-idle-time 5))

;; [tab-bar] Tab bar
(use-package tab-bar
  :hook (after-init . tab-bar-mode)
  :bind* (("M-t" . tab-new)
          ("M-q" . tab-close)
          ("M-<tab>" . tab-next)
          ("M-S-<tab>" . tab-previous))
  :config
  (setq tab-bar-separator ""
        tab-bar-new-tab-choice "*scratch*"
        tab-bar-tab-name-truncated-max 20
        tab-bar-auto-width nil
        tab-bar-close-button-show nil
        tab-bar-tab-hints t
        tab-bar-show 1
        tab-bar-select-tab-modifiers '(meta))

  ;; truncate for [tab name] and add count
  (setq tab-bar-tab-name-format-functions
        '(tab-bar-tab-name-format-hints
          tab-bar-tab-name-format-truncated
          (lambda (name &rest _) (concat " " name " "))
          tab-bar-tab-name-format-face))

  (defvar +tab-bar-telega-indicator-cache nil)
  (defvar +tab-bar-emms-indicator-cache nil)
  (defvar +tab-bar-org-agenda-indicator-cache nil)

  (setq tab-bar-format '((lambda () +tab-bar-org-agenda-indicator-cache)
                         (lambda () +tab-bar-telega-indicator-cache)
                         (lambda () +tab-bar-emms-indicator-cache)
                         tab-bar-format-tabs))

  (with-eval-after-load 'agent-shell-attention
    (add-to-list 'tab-bar-format 'agent-shell-attention-tab-bar-format))

  (with-eval-after-load 'appt
    (defadvice! +tab-bar-org-agenda-indicator-update (&rest _)
      :after '(appt-check org-agenda-to-appt)
      (let* ((count (length appt-time-msg-list))
             (notification (and appt-mode-string (cadar appt-time-msg-list)))
             (preview (and notification
                           (truncate-string-to-width notification 24 nil nil "…")))
             (text (propertize (format " %d%s " count
                                       (if preview (concat " " preview) ""))
                               'face 'font-lock-keyword-face)))
        (setq +tab-bar-org-agenda-indicator-cache
              `((tab-bar-org-agenda menu-item ,text
                                    (lambda ()
                                      (interactive)
                                      (org-agenda-list nil nil 'day))))))
      (force-mode-line-update t))
    (+tab-bar-org-agenda-indicator-update))

  (with-eval-after-load 'telega
    (defadvice! +tab-bar-telega-indicator-update (&rest _)
      :after '(telega--on-updateUnreadChatCount
               telega--on-updateChatUnreadMentionCount
               telega--on-updateChatUnreadReactionCount)
      "Update the cached Telega status in the tab bar."
      (when (and (featurep 'telega)
                 (telega-server-live-p))
        (setq +tab-bar-telega-indicator-cache
              (let* ((chats (telega-chats-list))
                     (online-p (funcall telega-online-status-function))
                     (unread-count (or (plist-get telega--unread-chat-count :unread_unmuted_count) 0))
                     (mention-count (apply #'+ (mapcar (telega--tl-prop :unread_mention_count)
                                                       (telega-filter-chats chats '(and is-known mention)))))
                     (reaction-count (apply #'+ (mapcar (telega--tl-prop :unread_reaction_count)
                                                        (telega-filter-chats chats '(and is-known unread-reactions)))))
                     (count (+ unread-count mention-count reaction-count))
                     (text (propertize (concat " T" (unless (zerop count) (number-to-string count)) " ")
                                       'face `(:inherit font-lock-keyword-face :inverse-video ,online-p))))
                `((tab-bar-telega menu-item ,text telega
                                  :help "Open Telega"))))))

    (add-hook! (telega-ready-hook
                telega-chats-fetched-hook
                telega-kill-hook
                telega-online-status-hook)
      #'+tab-bar-telega-indicator-update))

  (with-eval-after-load 'emms
    (defun +tab-bar-emms-indicator-update (&rest _)
      "Update the cached EMMS track indicator in the tab bar."
      (setq +tab-bar-emms-indicator-cache
            (when (and (bound-and-true-p emms-player-playing-p))
              (let ((text
                     (propertize (concat " " (if emms-player-paused-p "Ⅱ" "♫") " ")
                                 'face 'font-lock-keyword-face)))
                `((tab-bar-emms menu-item ,text emms-ui-now-playing
                                :help "Open EMMS Now Playing"))))))

    (add-hook! (emms-player-started-hook
                emms-player-paused-hook
                emms-player-stopped-hook
                emms-player-finished-hook)
      :append #'+tab-bar-emms-indicator-update)
    (+tab-bar-emms-indicator-update))

  ;; WORKAROUND: fresh tab-bar for daemon
  (add-hook! (server-after-make-frame-hook window-setup-hook) :call-immediately
    (defun +refresh-tab-bar (&rest _)
      (tab-bar--update-tab-bar-lines)
      (force-mode-line-update))))
