;;; -*- lexical-binding: t -*-

;; Prefer side-by-side splits on wide frames (stock split-width-threshold is 150
;; columns; with large CJK fonts a "maximized" frame can still be < 150 cols and
;; stay vertical).  120 is a practical default for Sarasa 16pt on modern displays.
(setq split-width-threshold 120
      split-height-threshold 80)

(defun +window-rotate-stacked-if-two-vertical (&rest _)
  "If FRAME has exactly two vertically stacked windows, rotate to side-by-side.
Shared by maximize and true fullscreen (macOS often uses `fullboth', not
`maximized', so an advice only on `toggle-frame-maximized' never fired)."
  (let* ((frame (selected-frame))
         (fs (frame-parameter frame 'fullscreen))
         (wins (window-list frame 'no-minibuf)))
    (when (and (memq fs '(maximized fullboth fullwidth fullheight))
               (= (length wins) 2)
               ;; nil AXIS ⇒ vertical combination (top/bottom stack).
               (window-combined-p (car wins) nil))
      (with-selected-frame frame
        (window-layout-rotate-anticlockwise (frame-root-window frame))))))

(advice-add #'toggle-frame-maximized :after #'+window-rotate-stacked-if-two-vertical)
(advice-add #'toggle-frame-fullscreen :after #'+window-rotate-stacked-if-two-vertical)

;; [ace-window] Add number for each window
(use-package ace-window
  :straight t
  :custom-face
  (aw-leading-char-face ((t (:inherit font-lock-keyword-face :bold t :height 3.0))))
  (aw-minibuffer-leading-char-face ((t (:inherit font-lock-keyword-face :bold t :height 1.0))))
  ;; (aw-mode-line-face ((t (:inherit mode-line-emphasis :bold t))))
  :hook ((window-configuration-change . aw-update)) ;; For modeline
  ;; (add-hook 'after-make-frame-functions #'aw--after-make-frame t)
  :config
  (setq aw-background nil
        aw-ignore-current t)

  ;; Select window via `M-1'...`M-9'
  (defun +aw--select-window (number)
    "Select the specified window."
    (let* ((window-list (aw-window-list))
           (target-window nil))
      (cl-loop for win in window-list
               when (and (window-live-p win)
                         (eq number
                             (string-to-number
                              (window-parameter win 'ace-window-path))))
               do (setq target-window win)
               finally return target-window)

      ;; Select the target window if found
      (if target-window
          (aw-switch-to-window target-window)
        (message "No specified window: %d" number))))

  (dotimes (n 9)
    (bind-key (format "C-%d" (1+ n))
              (lambda ()
                (interactive)
                (+aw--select-window (1+ n))))))


;; [winner] Window-layout undo/redo (stock keys C-c <left>/<right>).
;; Do not set winner-dont-bind-my-keys t without rebinding — mode would
;; record history but stay key-dead (audit silent-nop).
(use-package winner
  :hook (after-init . winner-mode)
  :config
  (setq winner-boring-buffers
        '("*Completions*" "*Compile-Log*" "*inferior-lisp*" "*Fuzzy Completions*"
          "*Apropos*" "*Help*" "*cvs*" "*Buffer List*" "*Ibuffer*"
          "*esh command on file*")))


;; [popper] Enforce rules for popup windows like *Help*
(use-package popper
  :straight t
  :bind (:map popper-mode-map
              ("C-M-<tab>"   . popper-cycle)
              ("M-`" . popper-toggle-type))
  :hook (emacs-startup . popper-mode)
  :init
  (setq +popper-reference-buffers-select
        '("\\*Messages\\*"
          "Output\\*$" "\\*Pp Eval Output\\*$"
          "\\*Compile-Log\\*"
          "\\*Completions\\*"
          "\\*Async Shell Command\\*"
          "\\*Apropos\\*"
          "\\*Backtrace\\*"
          "\\*Calendar\\*"
          ;; "\\*Embark Actions\\*"
          "\\*Finder\\*"
          ;; `ibuffer' displays the buffer before enabling `ibuffer-mode',
          ;; so the first display has to match by name.
          "^\\*Ibuffer\\*$"
          "\\*Kill Ring\\*"

          bookmark-bmenu-mode
          comint-mode
          compilation-mode
          ibuffer-mode
          help-mode
          tabulated-list-mode
          Buffer-menu-mode
          flymake-diagnostics-buffer-mode

          ;; grep-mode occur-mode rg-mode
          osx-dictionary-mode

          "^\\*Process List\\*" process-menu-mode

          ;; `+eshell-toggle' displays this buffer before `eshell-mode'
          ;; is active, so the first display has to match by name.
          "^Eshell-popup: .*$" eshell-mode
          "^\\*shell.*\\*.*$"  shell-mode
          "^\\*terminal.*\\*.*$" term-mode
          "^\\*eldoc.*\\*.*$" eldoc-mode

          "\\*[Wo]*Man.*\\*$"
          "\\*ert\\*$"
          "\\*gud-debug\\*$"
          "\\*quickrun\\*$"
          "\\*vc-.*\\*$"
          "^\\*macro expansion\\**"
          reb-mode

          "\\*Agenda Commands\\*" "\\*Org Select\\*" "\\*Capture\\*" "^CAPTURE-.*\\.org*"
          "\\*Graphviz Preview: .*\\*"

          gptel-mode
          ;; ghostel-mode intentionally omitted: dakra opens terminals via
          ;; same-window (display-buffer--same-window-action); Popper bottom
          ;; half-splits fight that.  Use C-x m / C-x p m without popup wrap.

          (lambda (buffer)
            (with-current-buffer buffer
              (and (derived-mode-p 'compilation-mode)
                   (not (derived-mode-p 'grep-mode)))))
          ))
  (setq +popper-reference-buffer-no-select
        '("\\*Warnings\\*"))
  (setq popper-reference-buffers (append +popper-reference-buffers-select
                                         +popper-reference-buffer-no-select))
  :config
  ;; mode-line indicator
  (with-eval-after-load 'popper
    (setq popper-mode-line
          '(:eval `(:propertize " POP |"
                                face (:inherit +mode-line-meta-face
                                               :inverse-video ,(mode-line-window-selected-p))))))

  ;; Enable indicator in minibuffer
  (popper-echo-mode 1)

  ;; HACK: close popper with `C-g'
  (defadvice! +popper-close-window-hack (&rest _)
    :before #'keyboard-quit
    (when (and (called-interactively-p 'interactive)
               (not (region-active-p))
               popper-open-popup-alist)
      (let ((window (caar popper-open-popup-alist)))
        (when (window-live-p window)
          (delete-window window)))))

  ;; No-select list is matched via public patterns only (avoid popper--*
  ;; internal unpack vars, which break across popper versions).
  (defun +popper-match-reference-p (buffer entries)
    "Return non-nil if BUFFER matches any ENTRY in ENTRIES.
ENTRY may be a regexp string, major-mode symbol, or predicate."
    (let ((name (buffer-name buffer))
          (mode (buffer-local-value 'major-mode buffer)))
      (cl-some
       (lambda (entry)
         (cond
          ((stringp entry) (string-match-p entry name))
          ((symbolp entry) (provided-mode-derived-p mode entry))
          ((functionp entry) (funcall entry buffer))))
       entries)))

  (defun +popper-smart-popup (buffer &optional alist)
    "Display BUFFER as a half-height popup; select unless no-select listed."
    (let ((window (display-buffer-in-direction
                   buffer
                   (append alist '((direction . below)
                                   (window-height . 0.5))))))
      (unless (+popper-match-reference-p buffer +popper-reference-buffer-no-select)
        (select-window window))
      window))
  (setq popper-display-function #'+popper-smart-popup)
  )


;; [zoom] Managing the window sizes automatically
(use-package zoom
  :straight t
  :hook (window-setup . zoom-mode)
  :config
  (setq zoom-minibuffer-preserve-layout nil
        zoom-ignored-major-modes '(ediff-mode vundo-mode minibuffer-mode speedbar-mode))

  (add-hook! vundo-mode-hook
    (defun +zoom-fix-window-size-h ()
      (setq-local window-size-fixed t)))

  (add-hook! speedbar-mode-hook
    (defun +zoom-fix-window-width-h ()
      (setq-local window-size-fixed 'width)))

  (add-hook! ediff-mode-hook
    (defun +zoom-fix-window-height-h ()
      (setq-local window-size-fixed 'height))))

;; [auto-dim-other-buffers] Dim non-active buffers
(use-package auto-dim-other-buffers
  :straight t
  :hook ((after-init . auto-dim-other-buffers-mode))
  :config
  (setq auto-dim-other-buffers-dim-on-focus-out nil
        auto-dim-other-buffers-dim-on-switch-to-minibuffer nil)

  ;; `adob--rescan-windows' does not honor this option.
  (defadvice! +auto-dim-other-buffers-respect-minibuffer-option-a (fn)
    :around #'adob--rescan-windows
    (when (or auto-dim-other-buffers-dim-on-switch-to-minibuffer
              (not (window-minibuffer-p)))
      (funcall fn)))

  ;; 让行号也参与 dim
  (setq auto-dim-other-buffers-affected-faces
        (append
         auto-dim-other-buffers-affected-faces
         '((line-number
            . (auto-dim-other-buffers . nil))
           (line-number-current-line
            . (auto-dim-other-buffers . nil)))))

  ;; Never dim minibuffer
  (add-hook! auto-dim-other-buffers-never-dim-buffer-functions
    (defun +auto-dim-other-buffers-never-dim-minibuffer (buffer)
      "Keep minibuffer-backed UI buffers, such as Vertico buffer display, lit."
      (with-current-buffer buffer
        (minibufferp))))

  ;; Follow current theme
  (add-hook! (auto-dim-other-buffers-mode-hook enable-theme-functions server-after-make-frame-hook) :unless-daemonp-call-immediately
    (defun +auto-dim-other-buffers-auto-set-face (&rest _)
      (let ((dim (or (face-background 'mode-line)
                     'unspecified)))
        ;; Face renamed in auto-dim-other-buffers 2.2.1
        ;; (`auto-dim-other-buffers-face' is obsolete).
        (set-face-background 'auto-dim-other-buffers dim)
        (set-face-attribute 'auto-dim-other-buffers-hide nil
                            :foreground dim
                            :background dim))))
  )
