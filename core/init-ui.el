;; -*- lexical-binding: t; -*-

;; Optimization
(setq
 ;; Inhibits fontification while receiving input, which should help a little with scrolling performance.
 redisplay-skip-fontification-on-input t

 ;; [Selected-window]
 highlight-nonselected-windows nil
 cursor-in-non-selected-windows nil

 ;; Font compacting can be terribly expensive, but may increase memory use
 inhibit-compacting-font-caches t)


;; [Cursor] disable blinking
(blink-cursor-mode -1)


;; [Fringes] Reduce the clutter in the fringes
(setq indicate-buffer-boundaries nil
      indicate-empty-lines nil)

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


;; Indicate eob lines
(setq indicate-empty-lines t)


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
(setq minibuffer-prompt-properties '(read-only t
                                               cursor-intangible t
                                               face minibuffer-prompt))
(add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)
;; Allow emacs to query passphrase through minibuffer
(setq epg-pinentry-mode 'loopback)


;; Font: Same width and height for emoji, chinese and english characters
(defvar +font-size (if (eq system-type 'darwin) 14 26))

(add-hook! server-after-make-frame-hook :unless-daemonp-call-immediately
  (defun +setup-fonts ()
    "Setup fonts."
    (when (display-graphic-p)
      (set-face-attribute 'default nil :font (font-spec :family "MonoLisaCode" :size +font-size))
      (set-face-font 'fixed-pitch "MonoLisaCode")
      (set-face-font 'fixed-pitch-serif "MonoLisaCode")
      (set-face-font 'variable-pitch "MonoLisaText")

      ;; Sarasa Mono SC, JetBrains Maple Mono, LXGW WenKai Mono Screen
      (dolist (charset '(han cjk-misc))
        (set-fontset-font t charset (font-spec :family "LXGW WenKai Mono Screen")))

      ;; font for emoji, set as unicode to cover more chars
      (if (eq system-type 'darwin)
          (progn (set-fontset-font t 'unicode (font-spec :family "Apple Color Emoji") nil 'append)
                 (setq face-font-rescale-alist '(("Apple Color Emoji" . 0.79))))
        (set-fontset-font t 'unicode (font-spec :family "Noto Color Emoji") nil 'append)))))


;; Smooth Scroll (less "jumpy" than defaults)
(when (display-graphic-p)
  (setq mouse-wheel-scroll-amount '(2 ((shift) . hscroll) ((control) . nil))
        mouse-wheel-scroll-amount-horizontal 1
        mouse-wheel-progressive-speed nil))

;; Load theme
;; Don't prompt to confirm theme safety. This avoids problems with
;; first-time startup on Emacs > 26.3.
(setq custom-safe-themes t)


;; (use-package doom-themes
;;   :straight t
;;   :config
;;   (setq doom-themes-enable-bold t
;;         doom-themes-enable-italic t)
;;
;;   (doom-themes-org-config))

(use-package doric-themes
  ;; :straight (:type git
  ;;                  :host github
  ;;                  :repo "protesilaos/doric-themes")
  :demand t
  :load-path "/Users/dragon/code/doric-themes"
  :config
  (setq doric-themes-to-toggle '(doric-tiger doric-fire)))

;; (use-package modus-themes
;;   :straight t
;;   :demand t
;;   :init
;;   ;; can be built on top to provide their own "Modus" derivatives.
;;   ;; For example, this is what I do with my `ef-themes' and
;;   ;; `standard-themes' (starting with versions 2.0.0 and 3.0.0,
;;   ;; respectively).
;;   ;;
;;   ;; The `modus-themes-include-derivatives-mode' makes all Modus
;;   ;; commands that act on a theme consider all such derivatives, if
;;   ;; their respective packages are available and have been loaded.
;;   ;;
;;   ;; Note that those packages can even completely take over from the
;;   ;; Modus themes such that, for example, `modus-themes-rotate' only
;;   ;; goes through the Ef themes (to this end, the Ef themes provide
;;   ;; the `ef-themes-take-over-modus-themes-mode' and the Standard
;;   ;; themes have the `standard-themes-take-over-modus-themes-mode'
;;   ;; equivalent).
;;   ;;
;;   ;; If you only care about the Modus themes, then (i) you do not need
;;   ;; to enable the `modus-themes-include-derivatives-mode' and (ii) do
;;   ;; not install and activate those other theme packages.
;;   (modus-themes-include-derivatives-mode 1)
;;   :config
;;   ;; Your customizations here.  All customizations must evaluated
;;   ;; BEFORE loading the theme.
;;   (setq modus-themes-to-toggle '(modus-operandi modus-vivendi)
;;         modus-themes-to-rotate modus-themes-items
;;         ;; modus-themes-mixed-fonts t
;;         ;; modus-themes-variable-pitch-ui t
;;         modus-themes-italic-constructs t
;;         modus-themes-bold-constructs t
;;         modus-themes-completions '((t . (bold)))
;;         modus-themes-prompts '(bold)
;;         modus-themes-headings
;;         '((agenda-structure . (variable-pitch light 2.2))
;;           (agenda-date . (variable-pitch regular 1.3))
;;           (t . (regular 1.15))))
;;
;;   (setq modus-themes-common-palette-overrides nil)
;;
;;   ;; Finally, load your theme of choice (or a random one with
;;   ;; `modus-themes-load-random', `modus-themes-load-random-dark',
;;   ;; `modus-themes-load-random-light').
;;   (modus-themes-load-theme 'modus-operandi))

(defvar +light-theme 'doric-beach) ;; doom-gruvbox-light doric-tiger
(defvar +dark-theme 'doric-water)        ;; doom-gruvbox doric-lion

;; (defvar +light-theme 'modus-operandi) ;; modus-operandi-tinted
;; (defvar +dark-theme 'modus-vivendi)    ;; modus-vivendi-tinted

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
  :hook ((prog-mode markdown-mode org-mode) . ligature-mode)
  :config
  ;; Enable Sarasa/Iosevka ligatures in programming modes
  (ligature-set-ligatures '(prog-mode markdown-mode org-mode)
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
