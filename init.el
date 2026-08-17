;;; -*- lexical-binding: t -*-

(add-hook 'window-setup-hook
          (lambda ()
            (message "window-setup: %.3fs, after-init: %.3fs"
                     (float-time (time-subtract nil before-init-time))
                     (float-time (time-subtract after-init-time before-init-time)))))

;; Machine-local identity (gitignored). Copy private.el.example → private.el.
;; Declare before loading so private.el can `setq` them under lexical-binding.
(defvar +reddit-private-rss-user nil
  "Reddit username for the private r/emacs Atom URL.
Set in `private.el'.  When nil or empty, skip that feed.")
(defvar +magh-git-repo (expand-file-name "~/code/gh.el")
  "Local clone of magh.el (gh.el).  Override in `private.el'.")
(let ((private (expand-file-name "private.el" user-emacs-directory)))
  (when (file-readable-p private)
    (load private nil 'nomessage)))

(defvar +init-files (list
                     'init-util
                     'init-straight
                     'init-basic
                     'init-ui
                     'init-xterm
                     'init-ghostel
                     (when (eq system-type 'darwin) 'init-mac)
                     'init-completion
                     'init-tools
                     'init-highlight
                     'init-edit
                     'init-window
                     'init-dired
                     'init-shell
                     'init-prog
                     'init-scheme
                     'init-writing
                     'init-org
                     'init-vcs
                     'init-ibuffer
                     ;; 'init-ime
                     ;; 'init-modal
                     'init-modeline
                     'init-ai
                     'init-agent-shell
                     'init-social
                     'init-gnus
                     'init-elfeed
                     ;; 'init-media
                     'init-test
                     ))

(let ((init-directory (expand-file-name "core/" user-emacs-directory)))
  (dolist (file +init-files)
    (when file
      (load-file (concat init-directory (symbol-name file) ".el")))))
