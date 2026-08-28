;;; -*- lexical-binding: t -*-

;; [straight] Package manager config (should put setq before installation for `straight`)
(setq straight-check-for-modifications nil                   ; skip modification
      straight-vc-git-default-clone-depth '(1 single-branch) ; shadow clone
      ;; Do not permanently suppress-log 'native-compiler: that would ignore
      ;; display-warning entirely and cancel early-init's kind filter / debug-init.
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

;; Emacs 31 ships project/xref/tramp/org at the same major version as GNU ELPA.
;; Dependents (consult-dir, breadcrumb, geiser, tramp-rpc, md-babel, org-appear, …)
;; must not clone ELPA copies or we hit: Feature 'project' loaded from A is now
;; provided by B — and for org, a git 10.0-pre clone fighting dump Org 9.8.7.
;; Must be set before any package that declares a dependency on them.
;; `use-package org :straight (:type built-in)` in init-org.el is too late:
;; init-writing (md-babel) loads first and would register the org-elpa git recipe.
(setq straight-built-in-pseudo-packages
      (append '(project xref tramp org)
              straight-built-in-pseudo-packages))
(straight-use-package '(org :type built-in))

;; [use-package] config
(setq use-package-always-demand (daemonp)
      use-package-always-defer (not (daemonp))
      use-package-expand-minimally t
      use-package-enable-imenu-support t)


;; [straight-overview]
(use-package straight-overview
  :straight (:host github :repo "alberti42/straight-overview")
  :commands (straight-overview))
