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


;; [Fringes] Reduce the clutter in the fringes, but indicate eob lines
(setq indicate-buffer-boundaries nil
      indicate-empty-lines t)

;; Better fringe symbol
(let ((dots [#b00110000
             #b00110000
             #b00000000
             #b00110000
             #b00110000
             #b00000000
             #b00110000
             #b00110000]))
  (define-fringe-bitmap 'right-curly-arrow dots)
  (define-fringe-bitmap 'left-curly-arrow dots))
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
(setq minibuffer-prompt-properties '(read-only t
                                               intangible t
                                               cursor-intangible t
                                               face minibuffer-prompt))
(add-hook! minibuffer-setup-hook #'cursor-intangible-mode)
;; Allow emacs to query passphrase through minibuffer
(setq epg-pinentry-mode 'loopback)


;; CJK uses LXGW WenKai. It is proportional, so it is not the same width as PragmataPro.
(defconst +default-font "PragmataPro 14")
(defconst +org-font "PragmataPro Liga 14")

(defvar +default-fontset-configured-p nil
  "Non-nil after symbol and emoji entries have been added to the default fontset.")

(defun +set-face-family-like-default (face)
  "Make FACE use the family of `default' without fixing its size or style."
  (set-face-attribute face nil
                      :family (face-attribute 'default :family nil 'default)
                      :height 'unspecified
                      :weight 'unspecified
                      :slant 'unspecified))

(add-hook! org-mode-hook
  (defun +org-set-buffer-font ()
    "Set this Org buffer's face to `+org-font'."
    (let ((face 'org-mode-font-face))
      (unless (facep face)
        (make-face face))
      (set-face-attribute face nil :font +org-font)
      (buffer-face-set face))))

(add-hook! server-after-make-frame-hook :unless-daemonp-call-immediately
  (defun +setup-fonts ()
    "Setup fonts."
    (when (display-graphic-p)
      (set-face-attribute 'default nil :font +default-font :weight 'normal)
      (dolist (face '(fixed-pitch fixed-pitch-serif variable-pitch))
        (+set-face-family-like-default face))

      (dolist (charset '(han kana hangul cjk-misc bopomofo))
        (set-fontset-font t charset (font-spec :family "LXGW WenKai")))

      ;; Symbol and emoji entries are prepended. Repeating that on every
      ;; frame would stack the same fallbacks.
      (unless +default-fontset-configured-p
        (setq use-default-font-for-symbols nil)
        (let (chosen)
          (dolist (family '("PragmataPro" "Apple Symbols"))
            (when (and (not chosen)
                       (find-font (font-spec :family family)))
              (set-fontset-font t 'symbol (font-spec :family family) nil 'prepend)
              (setq chosen t))))
        (when (find-font (font-spec :family "Apple Color Emoji"))
          (let ((spec (font-spec :family "Apple Color Emoji")))
            ;; Also cover EYE and CARD INDEX DIVIDERS, which macOS otherwise
            ;; draws as text. Do not use the `unicode' charset: that overrides
            ;; the Latin font.
            (dolist (target '(emoji #x1F441 #x1F5C2))
              (set-fontset-font t target spec))))
        (setq +default-fontset-configured-p t)))))


;; Smooth Scroll (less "jumpy" than defaults)
(setq mouse-wheel-scroll-amount '(2 ((shift) . hscroll) ((control) . nil))
      mouse-wheel-scroll-amount-horizontal 1
      mouse-wheel-progressive-speed nil)

;; Load theme
;; Don't prompt to confirm theme safety. This avoids problems with
;; first-time startup on Emacs > 26.3.
(setq custom-safe-themes t)


(use-package ashen
  :straight (:host github :repo "LuciusChen/ashen")
  :demand t)

(defvar +light-theme 'ashen-day)
(defvar +dark-theme 'ashen-night)
(defvar +system-appearance nil
  "Last reported system appearance, either `light' or `dark'.")

(defun +system-appearance-changed (appearance)
  "Remember APPEARANCE and update the theme using a graphical frame."
  (setq +system-appearance appearance)
  ;; Notifications may arrive while a terminal frame is selected.
  (when-let* ((frame (seq-find #'display-graphic-p (frame-list))))
    (with-selected-frame frame
      (+load-theme))))

(add-hook! tty-setup-hook :unless-daemonp-call-immediately
  (defun +load-theme (&optional theme)
    "Load THEME, or choose a theme matching the system or terminal."
    (setq theme
          (or theme
              (if (eq (if (display-graphic-p)
                          (or +system-appearance
                              (and (boundp 'ns-system-appearance) ns-system-appearance)
                              'dark)
                        (or (terminal-parameter nil 'background-mode)
                            (frame-parameter nil 'background-mode)))
                      'dark)
                  +dark-theme
                +light-theme)))
    (unless (member theme custom-enabled-themes)
      (mapc #'disable-theme custom-enabled-themes)
      (load-theme theme t))))

(add-hook! after-make-frame-functions
  (defun +load-theme-for-frame (frame)
    "Choose the theme for a newly created graphical FRAME."
    (when (display-graphic-p frame)
      (with-selected-frame frame
        (+load-theme)))))

;; [window-divider] Display window divider
(setq window-divider-default-places t
      window-divider-default-bottom-width 1
      window-divider-default-right-width 1)
(add-hook! window-setup-hook #'window-divider-mode)


;; [ligature] ligature support for Emacs
(use-package ligature
  :straight t
  ;; Org hides emphasis delimiters with text properties.  Font ligatures can
  ;; still shape those invisible delimiters together with visible content
  ;; (for example, the final `*=' in `=path/**='), leaking part of the hidden
  ;; delimiter into the rendered glyph.  Keep ligatures out of Org buffers.
  :hook (prog-mode . ligature-mode)
  :config
  ;; Enable MonoLisaCode ligatures in programming modes
  (ligature-set-ligatures '(prog-mode)
                          '(;; Arrows
                            "<-" "<--" "<---" "<<-" "<-<" "->" "->>" "-->"
                            "--->" ">->" "<->" "<-->" "<--->" "<---->"
                            "<=" "<==" "<===" "<<=" "<=<" "=>" "=>>" "==>"
                            "===>" ">=>" "<=>" "<==>" "<===>" "<====>" ">>="
                            "<~" "<~~" "<~~~" "<<~" "<~<" "~>" "~>>" "~~>"
                            "~~~>" ">~>" "<~>" "<~~>" "<~~~>" "<~~~~>"
                            ;; Tags and triangles
                            "<!--" "<!---" "</" "/>" "</>" "<>" "<|" "<||"
                            "<|||" "<|>" "|>" "||>" "|||>"
                            ;; Equality, chaining, and centered operators
                            "==" "===" "!=" "!==" "!===" ">=" "<<" "<<<" ">>" ">>>"
                            ":=" ":-" ":+" "<*" "<*>" "*>" "+:" "-:" "=:"
                            "<***>" "<:" ":>" "*-" "-*" "*=" "=*" "*+" "+*"
                            "<:>" ">*" "*<" "::=" ":<" ">:" "~=" "~-" "-~"
                            ;; Comments, punctuation, and connected runs
                            "/*" "*/" "::" ":::" "!!" "!!." ".." "..." ".?"
                            "?:" "?." "??" ";;" "||" "|||" "//" "///" "\\\\"
                            "+++" "++++" "---" "----" "___" "____" "###" "####"
                            "~~~" "~~~~")))


;; [scrollview] Show scroll progress in the fringe
(use-package scrollview
  :straight (:type git :host github :repo "roife/scrollview.el" :branch "main")
  :hook ((after-init . global-scrollview-mode))
  :config
  (setq scrollview-refresh-delay 0.1
        scrollview-update-interval 0.01))

(setq frame-title-format
      '((:eval (or buffer-file-truename "%b"))))
