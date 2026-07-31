;;; -*- lexical-binding: t -*-

;;; Minibuffer

(use-package vertico
  :straight (:files (:defaults "extensions/*.el"))
  :bind (:map vertico-map
              ("TAB" . minibuffer-complete)
              ("<tab>" . minibuffer-complete)
              ("C-<return>" . vertico-exit-input)
              ("C-, ." . vertico-quick-jump))
  :hook ((after-init . vertico-mode))
  :config
  (setq vertico-cycle t
        vertico-count 15)

  ;; WORKAROUND: https://github.com/minad/vertico#problematic-completion-commands
  (setq org-refile-use-outline-path 'file
        org-outline-path-complete-in-steps nil))


(use-package vertico-directory
  :straight nil
  :after vertico
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  ;; Cleans up path when moving directories with shadowed paths syntax.
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))


(use-package vertico-quick
  :straight nil
  :after vertico
  :bind (:map vertico-map
              ("C-," . vertico-quick-jump)))


(use-package vertico-buffer
  :straight nil
  :after vertico
  :hook (vertico-mode . vertico-buffer-mode)
  :config
  (setq vertico-buffer-display-action '(display-buffer-in-direction
                                        (direction . below)
                                        (window-height . 0.5)))
  (defadvice! +vertico-buffer-disbale-mode-line ()
    :before #'vertico-buffer--setup
    (setq-local mode-line-format nil))
  )


;;; Matching styles

(use-package orderless
  :straight t
  :init
  ;; Component modifiers:
  ;;   !foo excludes, =foo matches literally, ~foo uses flex,
  ;;   ^foo matches a literal prefix, ,foo uses initialism,
  ;;   %foo enables char-folding, @foo matches annotations.
  (defun +orderless-dispatch (pattern _index _total)
    (cond
     ;; Ensure $ works with Consult: candidates may end with tofu chars for
     ;; disambiguation. Consult uses [#x100000, #x10FFFD] (consult--tofu-*),
     ;; not the old #x200000–#x300000 PUA range.
     ((string-suffix-p "$" pattern)
      (let ((tofu (if (boundp 'consult--tofu-regexp)
                      (concat consult--tofu-regexp "*")
                    "[\x100000-\x10FFFD]*")))
        `(orderless-regexp . ,(concat (substring pattern 0 -1) tofu "$"))))
     ((string= "!" pattern) `(orderless-literal . ""))
     ;; Prefer `orderless-not' over legacy `orderless-without-literal' (README).
     ((string-prefix-p "!" pattern) `(orderless-not . ,(substring pattern 1)))
     ((string-prefix-p "%" pattern) `(char-fold-to-regexp . ,(substring pattern 1)))
     ((string-suffix-p "%" pattern) `(char-fold-to-regexp . ,(substring pattern 0 -1)))
     ((string-prefix-p "^" pattern) `(orderless-literal-prefix . ,(substring pattern 1)))
     ((string-suffix-p "^" pattern) `(orderless-literal-prefix . ,(substring pattern 0 -1)))
     ((string-prefix-p "," pattern) `(orderless-initialism . ,(substring pattern 1)))
     ((string-suffix-p "," pattern) `(orderless-initialism . ,(substring pattern 0 -1)))
     ((string-prefix-p "=" pattern) `(orderless-literal . ,(substring pattern 1)))
     ((string-suffix-p "=" pattern) `(orderless-literal . ,(substring pattern 0 -1)))
     ((string-prefix-p "~" pattern) `(orderless-flex . ,(substring pattern 1)))
     ((string-suffix-p "~" pattern) `(orderless-flex . ,(substring pattern 0 -1)))
     ((string-prefix-p "@" pattern) `(orderless-annotation . ,(substring pattern 1)))
     ((string-suffix-p "@" pattern) `(orderless-annotation . ,(substring pattern 0 -1)))))

  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-ignore-case t
        read-buffer-completion-ignore-case t
        ;; `read-file-name-completion-ignore-case' is set once in init-basic
        ;; (darwin default is already t; keep the global explicit setq there).
        ;; eglot registers category `eglot-capf' only (no bare `eglot').
        completion-category-overrides '((file (styles partial-completion))
                                        (eglot-capf (styles orderless)))
        orderless-style-dispatchers '(+orderless-dispatch)
        ;; `completions-sort' only affects built-in *Completions*; Vertico ignores it.
        completion-pcm-leading-wildcard t))


(use-package marginalia
  :straight t
  :hook (vertico-mode . marginalia-mode))


;;; Actions and search commands

(use-package embark
  :straight t
  :bind (("C-." . embark-act)           ; 对当前目标执行动作（同 emacsredux 作者键位）
         ;; ("M-." . embark-dwim)          ; 对当前目标执行默认动作
         ("C-h B" . embark-bindings)    ; 列出所有 embark 绑定
         :map embark-file-map
         ("s" . sudo-edit)              ; 对文件: sudo 编辑
         ("g" . +embark-magit-status)   ; 对文件: 打开 magit-status
         :map minibuffer-local-map
         ("C-c C-c" . embark-export)    ; 导出候选项列表
         ("C-c C-o" . embark-collect))  ; 收集候选项到独立 buffer
  :init
  (setq prefix-help-command 'embark-prefix-help-command)
  :config
  ;; Embark buffer names are "*Embark Collect: …*" / "*Embark Live: …*"
  ;; (old "*Embark Collect Live/Completions*" names are obsolete).
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark \\(Collect\\|Live\\)\\b"
                 nil
                 (window-parameters (mode-line-format . none))))

  (defun +embark-magit-status (file)
    "Run `magit-status` on repo containing the embark target."
    (interactive "GFile: ")
    (magit-status (locate-dominating-file file ".git"))))


(use-package embark-consult
  :straight t
  :after (embark consult))


(use-package consult
  :straight t
  :bind (([remap bookmark-jump]                 . consult-bookmark)           ; C-x r b
         ([remap list-registers]                . consult-register)
         ([remap goto-line]                     . consult-goto-line)          ; M-g g
         ([remap imenu]                         . consult-imenu)
         ("M-s i"                               . consult-imenu)
         ("M-s I"                               . consult-imenu-multi)
         ([remap locate]                        . consult-locate)
         ([remap load-theme]                    . consult-theme)
         ([remap man]                           . consult-man)
         ([remap recentf-open-files]            . consult-recent-file)        ; C-x C-r
         ([remap switch-to-buffer]              . consult-buffer)             ; C-x b
         ([remap switch-to-buffer-other-window] . consult-buffer-other-window); C-x 4 b
         ([remap switch-to-buffer-other-frame]  . consult-buffer-other-frame) ; C-x 5 b
         ([remap yank-pop]                      . consult-yank-pop)           ; M-y
         ("M-s l"                               . consult-line)
         ("M-s r"                               . consult-ripgrep)
         ("M-s d"                               . consult-fd)
         :map minibuffer-mode-map
         ("M-r"                                 . consult-history))
  :config
  (setq consult-narrow-key "<"
        consult-async-min-input 2
        consult-async-refresh-delay 0.05)

  ;; [consult-register] Configure the register formatting.
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format)
  ;; This adds thin lines, sorting and hides the mode line of the window.
  (advice-add #'register-preview :override #'consult-register-window)

  ;; [consult-xref] Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  ;; better preview
  (consult-customize
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file
   consult-buffer
   :preview-key "s-p")
  (consult-customize
   consult-theme
   :preview-key (list "s-p" :debounce 0.6 'any)))


(use-package avy-embark-collect
  :straight (:host github :repo "oantolin/embark"
                   :files ("avy-embark-collect.el"))
  :after (embark avy)
  :bind (:map embark-collect-mode-map
              ("j" . avy-embark-collect-choose)
              ("J" . avy-embark-collect-act)))


;; [consult-dir] Insert path quickly in minibuffer
(use-package consult-dir
  :straight t
  :bind (([remap list-directory] . consult-dir)
         :map minibuffer-local-completion-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file))
  :config
  ;; `consult-dir--source-tramp-local' is already in the default sources list.
  (add-to-list 'consult-dir-sources 'consult-dir--source-tramp-ssh t))


;;; In-buffer completion

(use-package corfu
  :straight (:files (:defaults "extensions/*.el"))
  :hook (((prog-mode conf-mode yaml-mode yaml-ts-mode toml-ts-mode text-mode codex-ide-session-mode)
          . +corfu-enable)
         ;; Shells are not prog-mode; set auto nil *before* enabling Corfu.
         ((shell-mode eshell-mode) . +corfu-enable-no-auto)
         ;; Elisp: prog-mode-hook runs while major-mode is still prog-mode, so
         ;; disable auto only on the child mode hook, then restart Corfu.
         ((emacs-lisp-mode lisp-interaction-mode) . +corfu-disable-auto)
         (minibuffer-setup . +corfu-enable-in-minibuffer))
  :bind (:map corfu-map
              ("TAB" . corfu-complete)
              ("<tab>" . corfu-complete)
              ("S-TAB" . +corfu-move-to-minibuffer)
              ("S-<tab>" . +corfu-move-to-minibuffer)
              ("RET" . nil))
  :init
  (defun +corfu-enable ()
    "Enable Corfu (auto Capf on by default)."
    (corfu-mode 1))
  (defun +corfu-enable-no-auto ()
    "Enable Corfu with auto Capf off (shells)."
    (setq-local corfu-auto nil)
    (corfu-mode 1))
  (defun +corfu-disable-auto ()
    "Turn off auto Capf after Corfu is already on (Elisp security)."
    (setq-local corfu-auto nil)
    (when corfu-mode
      (corfu-mode -1)
      (corfu-mode 1)))
  :config
  (setq corfu-cycle t
        corfu-auto t
        corfu-auto-prefix 2
        corfu-preselect 'first
        corfu-preview-current nil
        ;; 0.1 was too aggressive with cape-dabbrev; 0.2 is the usual floor.
        corfu-auto-delay 0.2)

  ;; Emacs 30+: text-mode defaults to Ispell Capf; prefer Corfu/cape sources.
  (setq text-mode-ispell-word-completion nil)

  (defun +corfu-move-to-minibuffer ()
    "Use Consult's minibuffer UI for the current completion-in-region table."
    (interactive)
    (pcase completion-in-region--data
      (`(,beg ,end ,table ,pred ,extras)
       (let ((completion-extra-properties extras)
             completion-cycle-threshold completion-cycling)
         (consult-completion-in-region beg end table pred)))))
  (add-to-list 'corfu-continue-commands #'+corfu-move-to-minibuffer)

  (defun +corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      (corfu-mode 1))))

(use-package corfu-history
  :straight nil
  :after corfu
  :config
  (corfu-history-mode 1))

(use-package corfu-popupinfo
  :straight nil
  :after corfu
  :config
  (corfu-popupinfo-mode 1)
  (setq corfu-popupinfo-delay '(1.0 . 1.0)))

(use-package corfu-quick
  :straight nil
  :after corfu
  :bind (:map corfu-map
              ("C-, ," . corfu-quick-complete)))


(use-package cape
  :straight t
  :hook (((TeX-mode LaTeX-mode org-mode markdown-ts-mode) . +completion-add-tex-capfs))
  :init
  ;; cape 2.7+ defaults `cape-dabbrev-buffer-function' to `cape-same-mode-buffers'.

  (defun +completion-add-capfs (&rest capfs)
    "Append CAPFS to the buffer-local `completion-at-point-functions'."
    (dolist (capf capfs)
      (unless (memq capf completion-at-point-functions)
        (setq-local completion-at-point-functions
                    (append completion-at-point-functions (list capf))))))

  (setq-default completion-at-point-functions
                (append completion-at-point-functions (list #'cape-file #'cape-dabbrev)))

  (defun +completion-add-tex-capfs ()
    (+completion-add-capfs #'cape-tex)))


;;; Snippets

(use-package tempel
  :straight t
  :bind (:map tempel-map
              ("TAB" . tempel-next)
              ("<tab>" . tempel-next)
              ("S-<tab>" . tempel-previous)
              ("<backtab>" . tempel-previous))
  :hook (((prog-mode text-mode conf-mode) . +tempel-setup-capf)
         ((prog-mode text-mode) . tempel-abbrev-mode))
  :init
  (defvar +tempel-trigger-capf nil)

  (defun +tempel-setup-capf ()
    (unless +tempel-trigger-capf
      (setq +tempel-trigger-capf (cape-capf-trigger #'tempel-complete ?/)))
    (unless (memq +tempel-trigger-capf completion-at-point-functions)
      (setq-local completion-at-point-functions
                  (cons +tempel-trigger-capf completion-at-point-functions))))
  :config
  (setq tempel-path (expand-file-name "tempel-templates" user-emacs-directory)))


(use-package tempel-collection
  :straight t
  :after tempel)


(use-package dabbrev
  :config
  (setq dabbrev-ignored-buffer-regexps '("\\.\\(?:pdf\\|jpe?g\\|png\\)\\'")))
