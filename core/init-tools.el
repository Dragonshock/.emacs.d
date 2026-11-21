;;; -*- lexical-binding: t -*-

;; [speedbar]
(use-package speedbar
  :init
  (setq speedbar-prefer-window t
        speedbar-window-default-width 30))


;; [emureader] read docs in emacs.  The package renamed from `reader' and
;; its module from `render-core' to `emureader-dyn' (see its Makefile).
(use-package emureader
  :straight  `(emureader :type git :host codeberg :repo "MonadicSheep/emacs-reader"
                         :package "emureader" :local-repo "emacs-reader"
                         :files (:defaults ,(concat "emureader-dyn" module-file-suffix))
                         ;; The Makefile forces USE_PKGCONFIG off when it finds nix, then
                         ;; looks for a Homebrew mupdf.  A command-line assignment wins
                         ;; over that, and this machine's mupdf comes from Home Manager.
                         :pre-build ("make" "all" "CC=cc" "USE_PKGCONFIG=yes"
                                     ,(concat "PKG_CONFIG_PATH="
                                              (expand-file-name "~/.local/state/home-manager/gcroots/current-home/home-path/lib/pkgconfig")))))

(provide 'init-tools)
