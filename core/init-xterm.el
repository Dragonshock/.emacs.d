;;; -*- lexical-binding: t -*-

;; warp/truncation indicator in tty
;; NS dumps may not pre-load disp-table; ensure a live char-table first.
(require 'disp-table)
(unless (char-table-p standard-display-table)
  (setq standard-display-table (make-display-table)))
(set-display-table-slot standard-display-table
                        'wrap
                        (make-glyph-code ?↩ 'shadow))
(set-display-table-slot standard-display-table
                        'truncation
                        (make-glyph-code ?… 'shadow))

;; T2: do not setq-default auto-composition-mode to a non-nil string
;; ("xterm-256color" is truthy — composition stayed on).  Disable only
;; on TTY frames; GUI keeps the stock default (t).
(defun +xterm-disable-auto-composition (&optional frame)
  "Turn off `auto-composition-mode' on FRAME when it is a TTY."
  (let ((frame (or frame (selected-frame))))
    (when (and (frame-live-p frame)
               (not (display-graphic-p frame)))
      (with-selected-frame frame
        (auto-composition-mode -1)))))
(add-hook 'tty-setup-hook #'+xterm-disable-auto-composition)
(add-hook 'after-change-major-mode-hook #'+xterm-disable-auto-composition)


;; [Kitty Graphics Protocol] Implements support for Kitty's "graphics protocol",
;; which allows the terminal to display images and videos inline.
(use-package kitty-graphics
  :straight (:type git :host github :repo "cashmeredev/kitty-graphics.el")
  :hook (tty-setup . kitty-graphics-setup)
  :init
  (setq kitty-graphics-enable-video t))


;; [Kitty Keyboard Protocol] Implements support for Kitty's "keyboard protocol",
;; which allows the terminal to send key events to Emacs.
(use-package kkp
  :straight t
  ;; KKP maps C-g to CSI-u; call-process (e.g. envrc--export) cannot be
  ;; interrupted without restoring legacy keys around subprocesses.
  ;; README + both local/roife default nil → footgun with envrc-global-mode.
  :init
  (setq kkp-restore-legacy-keys-around-subprocesses t)
  :hook (tty-setup . global-kkp-mode))


;; [xterm]
(use-package term/xterm
  :straight nil
  ;; G2: Ghostty is not in Emacs 31's xterm-mouse allowlist (kitty/foot/
  ;; iTerm2 / alacritty / contour).  Upstream roife enables this on
  ;; tty-setup; a Lisp call with no arg enables (does not toggle).
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
