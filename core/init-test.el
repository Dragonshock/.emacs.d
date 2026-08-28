;;; -*- lexical-binding: t -*-

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
  ;; `eglot-events-buffer' uses `jsonrpc-events-buffer', not the
  ;; post-initialize renamed name.  Do not hook
  ;; `eglot-server-initialized-hook': it runs before initialize, and a
  ;; `let'-bound lambda capturing itself is evaluated outside the
  ;; binding (void-variable).
  (if-let* ((server (eglot-current-server)))
      (eglot-reconnect server)
    (call-interactively #'eglot))
  (when-let* ((server (eglot-current-server)))
    (eglot-events-buffer server)))
