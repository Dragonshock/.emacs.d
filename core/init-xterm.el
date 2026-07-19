;;; -*- lexical-binding: t -*-

;; warp/truncation indicator in tty
(set-display-table-slot standard-display-table
                        'wrap
                        (make-glyph-code ?↩ 'shadow))

(set-display-table-slot standard-display-table
                        'truncation
                        (make-glyph-code ?… 'shadow))


;; [Kitty Graphics Protocol] Implements support for Kitty's "graphics protocol",
;; which allows the terminal to display images and videos inline.
(use-package kitty-graphics
 :straight (:type git :host github :repo "cashmeredev/kitty-graphics.el")
 :hook (tty-setup . kitty-graphics-setup)
 :init
 (setq kitty-gfx-enable-video t))


;; [Kitty Keyboard Protocol] Implements support for Kitty's "keyboard protocol",
;; which allows the terminal to send key events to Emacs.
(use-package kkp
  :straight t
  :hook (tty-setup . global-kkp-mode)
  :init
  ;; KKP encodes C-g as an escape sequence, which Emacs can't detect at the
  ;; byte level — so C-g can't interrupt blocking synchronous subprocesses
  ;; (e.g. envrc/direnv `call-process').  This restores the legacy single-byte
  ;; C-g encoding around such calls.  Must be set before `global-kkp-mode'
  ;; first runs (the :hook above fires at tty-setup, after this :init).
  (setq kkp-restore-legacy-keys-around-subprocesses t))


;; []
;; NOTE: Emacs 31 may enable `xterm-mouse-mode' by default in compatible
;; terminals (including kitty).  Keep this hook for Emacs 30 and as a
;; fallback for non-compatible terminals.
(use-package term/xterm
  :straight nil
  :hook (tty-setup . xterm-mouse-mode)
  :init
  (setq xterm-extra-capabilities '(modifyOtherKeys reportBackground
                                   getSelection setSelection)
        xterm-set-window-title t)

  (defun +xterm-report-background ()
    "Query the terminal background color and reload the matching theme."
    (interactive)
    (unless (display-graphic-p)
      (require 'term/xterm)
      (xterm--query "\e]11;?\e\\"
                    '(("\e]11;" . xterm--report-background-handler))
                    t)
      (let ((bg-color (terminal-parameter nil 'xterm--background-color)))
        (when bg-color
          (apply #'xterm--set-background-mode bg-color)))
      (+load-theme)
      (message "Reported terminal background as %s"
               (terminal-parameter nil 'background-mode)))))
