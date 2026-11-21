;;; -*- lexical-binding: t -*-

(add-hook 'window-setup-hook
          (lambda ()
            (message "window-setup: %.3fs, after-init: %.3fs"
                     (float-time (time-subtract nil before-init-time))
                     (float-time (time-subtract after-init-time before-init-time)))))

;; Each entry maps to one `core/init-*.el', tangled from `emacs-config.org'.
;; The order IS the dependency order:
;;   init-util  first: every other module uses its `add-hook!' / `defadvice!'
;;   init-theme before init-platform: the platform files call
;;              `+system-appearance-changed' at load time.

(add-to-list 'load-path (expand-file-name "core" user-emacs-directory))

(require 'init-util)
(require 'init-straight)
(require 'init-core)
(require 'init-theme)
(require 'init-ui)
(require 'init-platform)
(require 'init-highlight)
(require 'init-modeline)
(require 'init-completion)
(require 'init-search)
(require 'init-edit)
(require 'init-window)
(require 'init-dired)
(require 'init-prog)
(require 'init-langs)
(require 'init-writing)
(require 'init-org)
(require 'init-agenda)
(require 'init-vcs)
(require 'init-tools)
(require 'init-mail)
(require 'init-web)
(require 'init-ai)
