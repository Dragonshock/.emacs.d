;;; -*- lexical-binding: t -*-

;; [straight] Package manager config (should put setq before installation for `straight`)
(setq straight-check-for-modifications nil                   ; skip modification
      straight-vc-git-default-clone-depth '(1 single-branch) ; shadow clone
      warning-suppress-log-types '((comp))                   ; Don't display comp warnings
      straight-disable-native-compile (not (native-comp-available-p)))

;; Make the running Emacs reachable as `emacs' for subprocesses.  Package
;; :pre-build steps shell out to it (emacs-reader's Makefile runs checkdoc via
;; `emacs'), and a macOS Emacs.app is not on PATH.  Must happen before any
;; package is built.
(let ((dir (and invocation-directory
                (directory-file-name (expand-file-name invocation-directory)))))
  (when (and dir (file-directory-p dir))
    (add-to-list 'exec-path dir)
    (let ((path (or (getenv "PATH") "")))
      (unless (string-match-p (regexp-quote dir) path)
        (setenv "PATH" (concat dir path-separator path))))))

;; Installation
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        user-emacs-directory))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; [use-package] config
(setq use-package-always-demand (daemonp)
      use-package-always-defer (not (daemonp))
      use-package-expand-minimally t
      use-package-enable-imenu-support t)


;; [straight-overview]
(use-package straight-overview
  :straight (:host github :repo "alberti42/straight-overview")
  :commands (straight-overview))
