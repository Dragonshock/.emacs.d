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

;; Theme config mirrors the doric-themes user surface (to-toggle / select /
;; rotate / load-random / after-load-hook), but loads modus-themes appearance.
;; Doric API  ->  Modus API
;;   doric-themes-to-toggle          -> modus-themes-to-toggle
;;   doric-themes-toggle             -> modus-themes-toggle
;;   doric-themes-to-rotate          -> modus-themes-to-rotate
;;   doric-themes-rotate             -> modus-themes-rotate
;;   doric-themes-select             -> modus-themes-select
;;   doric-themes-load-random        -> modus-themes-load-random
;;   doric-themes-load-theme         -> modus-themes-load-theme
;;   doric-themes-after-load-theme-hook -> modus-themes-after-load-theme-hook
(use-package modus-themes
  :straight t
  :demand t
  :config
  ;; Same role as former doric-themes-to-toggle.
  (setq modus-themes-to-toggle '(modus-operandi modus-vivendi)
        ;; nil => rotate through all themes from modus-themes-get-themes.
        modus-themes-to-rotate nil
        ;; Same idea as doric-themes-load-theme disabling other themes.
        modus-themes-disable-other-themes t)

  ;; Syntax highlighting: keep modus defaults (colourful semantic palette).
  ;; Do not force monochrome font-lock overrides.
  (setq modus-themes-italic-constructs nil
        modus-themes-bold-constructs nil)

  (defun +modus-themes--release-faces (faces)
    "Drop user-level specs for FACES so the active theme controls them."
    (dolist (face faces)
      (when (facep face)
        (face-spec-set face nil 'reset)
        (custom-theme-recalc-face face))))

  (defun +modus-themes-doric-style-faces ()
    "Restyle modus UI/chrome toward doric-themes; keep modus syntax colours.

UI diffs: fill-column, fringe, line numbers, links, prompt, selection,
flymake EOL (no box), org chrome, whitespace, matches, keys, popups,
tabs.  Font-lock and mode-line stay on modus defaults."
    ;; Clear earlier overrides that we no longer apply (user-level faces
    ;; from custom-set-faces would otherwise stick across reloads).
    (+modus-themes--release-faces
     '(font-lock-comment-face
       font-lock-comment-delimiter-face
       font-lock-doc-face
       font-lock-string-face
       font-lock-keyword-face
       font-lock-builtin-face
       font-lock-type-face
       font-lock-function-name-face
       font-lock-function-call-face
       font-lock-variable-name-face
       font-lock-variable-use-face
       font-lock-constant-face
       font-lock-preprocessor-face
       font-lock-warning-face
       mode-line
       mode-line-active
       mode-line-inactive))
    (modus-themes-with-colors
      (custom-set-faces
       ;; --- UI chrome -------------------------------------------------
       ;; doric: only :foreground → thin glyph stroke, not a filled cell.
       `(fill-column-indicator
         ((t :background unspecified :foreground ,bg-active)))
       ;; doric: fringe bg unspecified, accent-ish fg.
       `(fringe ((,c :background unspecified :foreground ,fg-alt)))
       `(margin ((,c :background unspecified :foreground ,fg-alt)))
       ;; doric: line-number = subtle fg only; current = bold + main.
       `(line-number
         ((,c :inherit default :background unspecified :foreground ,fg-dim)))
       `(line-number-current-line
         ((,c :inherit (bold default) :background unspecified :foreground ,fg-main)))
       ;; doric: underline + accent, no bg-link fill.
       `(link ((,c :background unspecified :foreground ,fg-alt :underline t)))
       `(link-visited ((,c :background unspecified :foreground ,fg-dim :underline t)))
       `(button ((,c :background unspecified :foreground ,fg-alt :underline t)))
       ;; doric: bold + intense-ish fg, no prompt background bar.
       `(minibuffer-prompt
         ((,c :inherit bold :background unspecified :foreground ,fg-dim)))
       ;; doric: current tab = main bg + bold; inactive = neutral gray strip.
       ;; Drop modus box padding so tabs stay flat.
       `(tab-bar ((,c :background ,bg-dim :foreground ,fg-dim :box unspecified)))
       `(tab-bar-tab
         ((,c :inherit bold :background ,bg-main :foreground ,fg-main :box unspecified)))
       `(tab-bar-tab-inactive
         ((,c :background ,bg-active :foreground ,fg-dim :box unspecified)))
       `(tab-bar-tab-group-current
         ((,c :inherit bold :background ,bg-main :foreground ,fg-alt :box unspecified)))
       `(tab-bar-tab-group-inactive
         ((,c :background ,bg-dim :foreground ,fg-dim :box unspecified)))
       `(tab-bar-tab-ungrouped
         ((,c :background ,bg-active :foreground ,fg-dim :box unspecified)))
       `(tab-line ((,c :background ,bg-dim :foreground ,fg-dim :height 1.0 :box unspecified)))
       `(tab-line-tab ((,c :inherit tab-line-tab-current)))
       `(tab-line-tab-current
         ((,c :inherit bold :background ,bg-main :foreground ,fg-main :box unspecified)))
       `(tab-line-tab-inactive
         ((,c :background ,bg-active :foreground ,fg-dim :box unspecified)))
       `(tab-line-tab-inactive-alternate
         ((,c :inherit tab-line-tab-inactive)))

       ;; --- selection / highlight ------------------------------------
       ;; doric region/paren = intense shadow; hl-line/vertico = accent bg.
       `(region ((,c :background ,bg-active :foreground ,fg-main)))
       `(secondary-selection ((,c :background ,bg-dim :foreground ,fg-dim)))
       `(hl-line ((,c :background ,bg-hl-line :extend t)))
       `(vertico-current ((,c :background ,bg-hl-line)))
       `(completions-highlight ((,c :background ,bg-hl-line)))
       `(corfu-current ((,c :background ,bg-active :foreground ,fg-main)))
       `(show-paren-match
         ((,c :background ,bg-active :foreground ,fg-main :underline unspecified)))
       `(isearch ((,c :background ,bg-active :foreground ,fg-main)))
       `(lazy-highlight
         ((,c :inherit italic :background unspecified :foreground ,fg-dim :underline t)))

       ;; --- flymake end-of-line ---------------------------------------
       ;; modus defaults use :box ,border (looks like a little window).
       ;; doric does not style these faces → plain text, no box.
       `(flymake-end-of-line-diagnostics-face
         ((,c :inherit italic :height 0.85 :box unspecified :background unspecified
              :foreground ,fg-dim)))
       `(flymake-error-echo-at-eol
         ((,c :inherit italic :height 0.85 :box unspecified :background unspecified
              :foreground ,err)))
       `(flymake-warning-echo-at-eol
         ((,c :inherit italic :height 0.85 :box unspecified :background unspecified
              :foreground ,warning)))
       `(flymake-note-echo-at-eol
         ((,c :inherit italic :height 0.85 :box unspecified :background unspecified
              :foreground ,info)))
       ;; echo (echo area) stays unboxed as well
       `(flymake-error-echo ((,c :foreground ,err :box unspecified)))
       `(flymake-warning-echo ((,c :foreground ,warning :box unspecified)))
       `(flymake-note-echo ((,c :foreground ,info :box unspecified)))
       ;; in-buffer underlines: keep wave like both themes; fringe chips
       ;; match doric's solid coloured markers more closely
       `(flymake-error
         ((,c :underline (:style wave :color ,underline-err) :box unspecified)))
       `(flymake-warning
         ((,c :underline (:style wave :color ,underline-warning) :box unspecified)))
       `(flymake-note
         ((,c :underline (:style wave :color ,underline-note) :box unspecified)))

       ;; --- org -------------------------------------------------------
       `(org-level-1 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-2 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-3 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-4 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-5 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-6 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-7 ((,c :inherit bold :foreground ,fg-main)))
       `(org-level-8 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-1 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-2 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-3 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-4 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-5 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-6 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-7 ((,c :inherit bold :foreground ,fg-main)))
       `(outline-8 ((,c :inherit bold :foreground ,fg-main)))
       `(org-block
         ((,c :inherit fixed-pitch :background ,bg-dim :extend t)))
       `(org-block-begin-line
         ((,c :inherit fixed-pitch :background ,bg-active :foreground ,fg-dim :extend t)))
       `(org-block-end-line
         ((,c :inherit org-block-begin-line)))
       `(org-code
         ((,c :inherit (fixed-pitch italic) :background unspecified :foreground ,fg-dim)))
       `(org-verbatim
         ((,c :inherit (fixed-pitch italic) :background unspecified :foreground ,fg-dim)))
       `(org-meta-line
         ((,c :inherit fixed-pitch :foreground ,fg-dim)))
       `(org-document-info-keyword
         ((,c :inherit fixed-pitch :foreground ,fg-dim)))
       `(org-drawer
         ((,c :inherit fixed-pitch :foreground ,fg-dim)))
       `(org-table
         ((,c :inherit fixed-pitch :foreground ,fg-alt)))

       ;; --- whitespace: fg only --------------------------------------
       `(whitespace-space ((,c :background unspecified :foreground ,bg-active)))
       `(whitespace-hspace ((,c :background unspecified :foreground ,bg-active)))
       `(whitespace-tab ((,c :background unspecified :foreground ,bg-active)))
       `(whitespace-newline ((,c :background unspecified :foreground ,bg-active)))
       `(whitespace-indentation ((,c :background unspecified :foreground ,bg-active)))
       `(whitespace-empty ((,c :background unspecified :foreground ,bg-active)))
       `(whitespace-big-indent ((,c :background ,bg-active :foreground unspecified)))

       ;; --- completion matches: underline/italic, less fill ----------
       `(orderless-match-face-0
         ((,c :inherit (bold italic) :background unspecified :foreground ,fg-main :underline t)))
       `(orderless-match-face-1
         ((,c :inherit italic :background unspecified :foreground ,fg-dim :underline t)))
       `(orderless-match-face-2
         ((,c :inherit italic :background unspecified :foreground ,fg-dim :underline t)))
       `(orderless-match-face-3
         ((,c :inherit italic :background unspecified :foreground ,fg-dim :underline t)))
       `(completions-common-part
         ((,c :inherit bold :background unspecified :foreground ,fg-main :underline t)))
       `(completions-first-difference
         ((,c :inherit italic :background unspecified :foreground ,fg-dim)))
       `(match ((,c :background ,bg-dim :foreground ,fg-dim)))

       ;; --- keys / help: bold-italic, less colour --------------------
       `(help-key-binding
         ((,c :inherit (fixed-pitch bold-italic) :background unspecified :foreground ,fg-main
              :box unspecified)))
       `(which-key-key-face
         ((,c :inherit (fixed-pitch bold-italic) :foreground ,fg-main)))
       `(transient-key
         ((,c :inherit (fixed-pitch bold-italic) :foreground ,fg-main)))
       `(embark-keybinding
         ((,c :inherit (fixed-pitch bold-italic))))

       ;; --- popups / tooltip softer ----------------------------------
       `(tooltip ((,c :background ,bg-dim :foreground ,fg-dim)))
       `(corfu-default
         ((,c :inherit fixed-pitch :background ,bg-dim :foreground ,fg-dim)))
       `(corfu-popupinfo
         ((,c :background ,bg-dim :foreground ,fg-dim)))
       `(company-tooltip
         ((,c :inherit fixed-pitch :background ,bg-dim :foreground ,fg-dim)))
       `(company-tooltip-selection
         ((,c :background ,bg-active :foreground ,fg-main))))))

  (add-hook 'modus-themes-after-load-theme-hook
            #'+modus-themes-doric-style-faces))

(defvar +light-theme 'modus-operandi) ; or modus-operandi-tinted
(defvar +dark-theme  'modus-vivendi)  ; or modus-vivendi-tinted

(add-hook! (tty-setup-hook server-after-make-frame-hook) :unless-daemonp-call-immediately
  (defun +load-theme (&optional theme)
    "Load THEME, or light/dark theme matching system appearance.
Prefer `modus-themes-load-theme' so `modus-themes-after-load-theme-hook'
runs and other themes are disabled consistently."
    (setq theme
          (or theme
              (if (if (display-graphic-p)
                      (cond ((eq system-type 'darwin) (eq ns-system-appearance 'dark))
                            (t t))
                    (eq (or (terminal-parameter nil 'background-mode)
                            (frame-parameter nil 'background-mode))
                        'dark))
                  +dark-theme
                +light-theme)))
    (unless (eq theme (car custom-enabled-themes))
      (if (fboundp 'modus-themes-load-theme)
          (modus-themes-load-theme theme)
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme theme t)))))

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
