;; -*- lexical-binding: t; -*-

;; Optimization
(setq
 ;; Inhibits fontification while receiving input, which should help a little with scrolling performance.
 redisplay-skip-fontification-on-input t

 ;; [Selected-window] — must be default/global (plain setq is buffer-local here).
 ;; Font compacting can be terribly expensive, but may increase memory use
 inhibit-compacting-font-caches t)
;; highlight-nonselected-windows stock default is already nil — do not setq.

(setq-default cursor-in-non-selected-windows nil)


;; [Cursor] disable blinking
(blink-cursor-mode -1)


;; [Fringes] Reduce the clutter in the fringes
;; indicate-buffer-boundaries stock default is already nil.
(setq-default indicate-empty-lines t)

;; Better fringe symbol
(define-fringe-bitmap 'right-curly-arrow
  [#b00110000
   #b00110000
   #b00000000
   #b00110000
   #b00110000
   #b00000000
   #b00110000
   #b00110000])
(define-fringe-bitmap 'left-curly-arrow
  [#b00110000
   #b00110000
   #b00000000
   #b00110000
   #b00110000
   #b00000000
   #b00110000
   #b00110000])
(define-fringe-bitmap 'right-arrow
  [#b00000000
   #b00000000
   #b00001110
   #b00001110
   #b00001110
   #b00000000
   #b00000000
   #b00000000])
(define-fringe-bitmap 'left-arrow
  [#b00000000
   #b00000000
   #b00000000
   #b01110000
   #b01110000
   #b01110000
   #b00000000
   #b00000000])


;; Allow [resize] by pixels.
(setq frame-resize-pixelwise t
      window-resize-pixelwise t)

;; Suppress GUI features for consistency
(setq use-file-dialog nil
      use-dialog-box nil)


;; Disable menu/tool/scroll bars in daemon/client frames
(add-hook! after-make-frame-functions
  (defun +disable-frame-chrome (&optional frame)
    "Keep daemon/client frames from restoring menu/tool/scroll bars."
    (let ((frame (or frame (selected-frame))))
      (when (frame-live-p frame)
        (set-frame-parameter frame 'menu-bar-lines 0)
        (set-frame-parameter frame 'tool-bar-lines 0)
        (set-frame-parameter frame 'vertical-scroll-bars nil)))))


;; [Minibuffer]
;; Allow minibuffer commands while in the minibuffer.
(setq enable-recursive-minibuffers t
      echo-keystrokes 0.02)
(use-package mb-depth
  :hook (after-init . minibuffer-depth-indicate-mode))
;; Keep the cursor out of the read-only portions of the minibuffer
;; `intangible' is obsolete since Emacs 25; cursor-intangible-mode handles this.
(setq minibuffer-prompt-properties '(read-only t
                                               cursor-intangible t
                                               face minibuffer-prompt))
(add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)
;; Allow emacs to query passphrase through minibuffer
(setq epg-pinentry-mode 'loopback)


;; Font: Same width and height for emoji, chinese and english characters
(defvar +font-size (if (eq system-type 'darwin) 14 26))

(defun +apply-default-frame-geometry-h (&optional frame force)
  "Re-apply 120x50 and center geometry for FRAME once after font setup.
Needed under `frame-inhibit-implied-resize' (early-init).  Skips frames that
already got this pass so `server-after-make-frame-hook' reusing a GUI frame
does not clobber maximized/custom sizes.  FORCE non-nil re-applies."
  (let ((frame (or frame (selected-frame))))
    (when (and (display-graphic-p frame)
               (or force (not (frame-parameter frame '+geometry-applied))))
      (with-selected-frame frame
        (set-frame-size frame 120 50)
        (modify-frame-parameters frame '((left . 0.5) (top . 0.5)))
        (set-frame-parameter frame '+geometry-applied t)))))

(add-hook! server-after-make-frame-hook :unless-daemonp-call-immediately
  (defun +setup-fonts ()
    "Setup fonts."
    (when (display-graphic-p)
      (set-face-attribute 'default nil :font (font-spec :family "TX-02" :size +font-size))
      (set-face-font 'fixed-pitch "TX-02")
      (set-face-font 'fixed-pitch-serif "TX-02") ; Sarasa Mono Slab SC
      (set-face-font 'variable-pitch "Sarasa UI SC")

      (dolist (charset '(han cjk-misc))
        (set-fontset-font t charset (font-spec :family "LXGW WenKai Mono"))) ; Sarasa Mono SC

      ;; Emoji script (Emacs 28+ NEWS); 'prepend so color emoji wins composition.
      ;; Do not bind color-emoji fonts to broad 'unicode — that can miss script
      ;; 'emoji entries or pull non-emoji glyphs into the emoji font.
      (if (eq system-type 'darwin)
          (progn (set-fontset-font t 'emoji (font-spec :family "Apple Color Emoji") nil 'prepend)
                 (setq face-font-rescale-alist '(("Apple Color Emoji" . 0.79))))
        (set-fontset-font t 'emoji (font-spec :family "Noto Color Emoji") nil 'prepend))
      ;; First graphic setup for this frame only (reused emacsclient frames skip).
      (+apply-default-frame-geometry-h))))

;; Non-daemon: window-setup after immediate +setup-fonts; once-guarded.
(add-hook 'window-setup-hook #'+apply-default-frame-geometry-h)


;; Smooth Scroll (less "jumpy" than defaults).
;; `mouse-wheel-scroll-amount' has a custom :set that reinstalls bindings;
;; plain setq leaves preloaded C-wheel text-scale. Harmless on TTY / daemon init.
(setopt mouse-wheel-scroll-amount '(2 ((shift) . hscroll) ((control) . nil))
        mouse-wheel-scroll-amount-horizontal 1
        mouse-wheel-progressive-speed nil)

;; Load theme
;; Don't prompt to confirm theme safety. This avoids problems with
;; first-time startup on Emacs > 26.3.
(setq custom-safe-themes t)


(use-package doom-themes
  :straight t
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)

  (doom-themes-org-config)
  (setcdr (assoc 'gnus-group-news-low-empty doom-themes-base-faces)
          '(:inherit 'gnus-group-mail-1-empty :weight 'normal)))

(defvar +light-theme 'doom-gruvbox-light)
(defvar +dark-theme 'doom-gruvbox)
;; Align with upstream roife: always re-detect dark/light and switch when the
;; picked theme differs.  First pass may run before xterm OSC 11; tty-setup-hook
;; re-runs after reportBackground so TUI can correct light → dark.
(add-hook! (tty-setup-hook server-after-make-frame-hook) :unless-daemonp-call-immediately
  (defun +load-theme (&optional theme)
    (setq theme (if (if (display-graphic-p)
                        (cond ((eq system-type 'darwin) (eq ns-system-appearance 'dark))
                              (t t))
                      (eq (or (terminal-parameter nil 'background-mode)
                              (frame-parameter nil 'background-mode))
                          'dark))
                    +dark-theme
                  +light-theme))
    (unless (member theme custom-enabled-themes)
      (mapc #'disable-theme custom-enabled-themes)
      (load-theme theme t))))

;; [window-divider] Display window divider
(setq window-divider-default-places t
      window-divider-default-bottom-width 1
      window-divider-default-right-width 1)
(add-hook 'window-setup-hook #'window-divider-mode)


;; [ligature] ligature support for Emacs
(use-package ligature
  :straight t
  :hook ((prog-mode markdown-ts-mode org-mode) . ligature-mode)
  :config
  ;; Enable Sarasa/Iosevka ligatures in programming modes
  (ligature-set-ligatures '(prog-mode markdown-ts-mode org-mode)
                          '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "||=" "||>"
                            ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "!=="
                            "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
                            "<~~" "<~>" "<*>" "<||" "<|>" "<==" "<=>" "<=<" "<->"
                            "<--" "<-<" "<<=" "<<-" "<<<" "</>" "###" "..<"
                            "..." "+++" "/==" "///" "~=" "~>" "~-" "*>" "*/"
                            "||" "|>" "::" ":=" ":>" ":<" "==" "=>" "!=" "!!" ">:"
                            ">=" ">>" "-~" "->" "<~" "<*" "<:" "<=" "<>"
                            "<-" "<<" "</" ".." ".?" "?:" "?." "??" ";;" "/*"
                            "/>" "//" "\\\\" "://"))
  )


;; [scrollview] Show scroll progress in the fringe
(use-package scrollview
  :straight (:type git :host github :repo "roife/scrollview.el" :branch "main")
  :hook ((after-init . global-scrollview-mode)))

(setq frame-title-format
      '((:eval (or buffer-file-truename "%b"))))
