;;; -*- lexical-binding: t -*-

;; chirp moved to init-social.el (upstream layout).

;; NOTE: upstream registers its own `vide' verilog LSP here via an absolute
;; path under ~roifewu; dropped since that binary does not exist in this fork.
;; The `eglot-x-enable-snippet-text-edit' setting was dropped too: eglot-x is
;; not installed.

(defun cargo-xtask-install-server ()
  (interactive)
  (let ((default-directory (locate-dominating-file default-directory "crates")))
    (if (and default-directory
             (string= (file-name-nondirectory (directory-file-name default-directory)) "rust-analyzer"))
        (progn
          (message "Running cargo xtask install --server")
          (compile "cargo xtask install --server --mimalloc")
          (message "Running cargo xtask install --server done"))
      (message "Not in rust-analyzer project")))
  )
;; Bind on both classic rust-mode and pure rust-ts-mode (treesit remap).
(with-eval-after-load 'rust-mode
  (define-key rust-mode-map (kbd "C-c C-x C-i") #'cargo-xtask-install-server))
(with-eval-after-load 'rust-ts-mode
  (define-key rust-ts-mode-map (kbd "C-c C-x C-i") #'cargo-xtask-install-server))

(defun restart-eglot-and-switch-logs ()
  "Reconnect Eglot in this buffer and display its events buffer."
  (interactive)
  (require 'eglot)
  (if-let* ((server (eglot-current-server)))
      (eglot-reconnect server)
    (call-interactively #'eglot))
  (when-let* ((server (eglot-current-server))
              (buf (jsonrpc-events-buffer server)))
    (display-buffer buf)))
