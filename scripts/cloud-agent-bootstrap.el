;;; cloud-agent-bootstrap.el --- Load this config in a Cloud Agent VM -*- lexical-binding: t -*-

;; This helper loads early-init.el + init.el the same way Emacs does at
;; startup, but wraps each core module load in a demoted-error handler so a
;; single package that cannot be built on this platform does not abort the
;; whole configuration.
;;
;; It is used by scripts/cloud-agent-install.sh to pre-build the straight.el
;; package tree, and by the `emacs-dev' launcher for an interactive session.
;;
;; Two packages in this configuration cannot be built on a Linux Cloud Agent
;; and are expected to be skipped here:
;;   * reader (emacs-reader) - :pre-build "make all" needs MuPDF >= 1.26 and a
;;     macOS "render-core.dylib"; Ubuntu ships an older MuPDF and builds a .so.
;;   * magh   - :repo points at a private local clone "/Users/.../gh.el" whose
;;     upstream was deleted, so it is unavailable off the author's machine.
;; Everything else is installed/built normally.

(defvar cloud-agent--failed-modules nil
  "Alist of (MODULE . ERROR) for core modules that failed to load.")

;; Ensure user-emacs-directory points at this repository checkout.
(setq user-emacs-directory
      (file-name-directory
       (directory-file-name
        (file-name-directory (or load-file-name buffer-file-name)))))

;; Continue past a core module whose load errors (e.g. an unbuildable
;; platform-specific package), recording the failure for a summary.
(advice-add
 'load-file :around
 (lambda (orig file)
   (let* ((name (file-name-nondirectory file))
          (core-module (string-prefix-p "init-" name)))
     (if (not core-module)
         (funcall orig file)
       (condition-case err
           (funcall orig file)
         (error
          (push (cons name err) cloud-agent--failed-modules)
          (message "cloud-agent-bootstrap: skipped %s: %S" name err)
          nil)))))
 '((name . cloud-agent-resilient-module-load)))

;; early-init.el is normally auto-loaded by Emacs; only load it here if it has
;; not run yet (detected via a variable it defines). This keeps `emacs -Q'
;; and `emacs -q' invocations consistent.
(unless (boundp '+gc-cons-threshold)
  (load (expand-file-name "early-init.el" user-emacs-directory) nil t))

(load (expand-file-name "init.el" user-emacs-directory) nil t)

(let ((failed (nreverse cloud-agent--failed-modules)))
  (if failed
      (message "cloud-agent-bootstrap: %d core module(s) had skipped packages: %s"
               (length failed)
               (mapconcat #'car failed ", "))
    (message "cloud-agent-bootstrap: all core modules loaded cleanly")))

(provide 'cloud-agent-bootstrap)
;;; cloud-agent-bootstrap.el ends here
