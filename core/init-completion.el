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
        vertico-resize nil
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
              ("M-q" . vertico-quick-jump)))


(use-package vertico-multiform
  :straight nil
  :after vertico
  :hook (vertico-mode . vertico-multiform-mode)
  :config
  (setq vertico-buffer-display-action
        '((display-buffer-reuse-window display-buffer-pop-up-window))
        vertico-multiform-commands
        '((consult-fd buffer)
          (consult-grep buffer)
          (consult-git-grep buffer)
          (consult-imenu buffer)
          (consult-imenu-multi buffer)
          (consult-line buffer)
          (consult-locate buffer)
          (consult-ripgrep buffer)
          (consult-register grid))
        vertico-multiform-categories
        '((consult-grep buffer)
          (consult-location buffer)
          (imenu buffer)
          (kill-ring grid))))


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
     ;; Ensure $ works with Consult commands, which add disambiguation suffixes
     ((string-suffix-p "$" pattern) `(orderless-regexp . ,(concat (substring pattern 0 -1) "[\x200000-\x300000]*$")))
     ((string= "!" pattern) `(orderless-literal . ""))
     ((string-prefix-p "!" pattern) `(orderless-without-literal . ,(substring pattern 1)))
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
        read-file-name-completion-ignore-case t
        completion-category-overrides '((file (styles basic partial-completion))
                                        (eglot (styles orderless))
                                        (eglot-capf (styles orderless)))
        orderless-style-dispatchers '(+orderless-dispatch)
        orderless-component-separator #'orderless-escapable-split
        completions-sort 'historical
        completion-pcm-leading-wildcard t))


(use-package marginalia
  :straight t
  :hook (vertico-mode . marginalia-mode))


;;; Actions and search commands

(use-package embark
  :straight t
  :bind (("C-." . embark-act)           ; 对当前目标执行动作
         ;; ("M-." . embark-dwim)          ; 对当前目标执行默认动作
         ("s-." . embark-dwim)
         ("C-h B" . embark-bindings)    ; 列出所有 embark 绑定
         :map embark-file-map
         ("s" . sudo-edit)              ; 对文件：sudo 编辑
         ("g" . +embark-magit-status)   ; 对文件：打开 magit-status
         :map minibuffer-local-map
         ("C-c C-c" . embark-export)    ; 导出候选项列表
         ("C-c C-o" . embark-collect))  ; 收集候选项到独立 buffer
  :init
  ;; 用 embark-prefix-help-command 替代默认的前缀帮助
  (setq prefix-help-command 'embark-prefix-help-command)
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
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
  :bind (;; --- 全局 remap（替换 Emacs 内置命令）---
         ([remap bookmark-jump]                 . consult-bookmark) ; C-x r b
         ([remap list-registers]                . consult-register)
         ([remap goto-line]                     . consult-goto-line) ; M-g g
         ([remap imenu]                         . consult-imenu)
         ("C-c i"                               . consult-imenu)
         ("C-c I"                               . consult-imenu-multi)  ; 多 buffer imenu
         ([remap locate]                        . consult-locate)
         ([remap load-theme]                    . consult-theme)        ; 主题切换带预览
         ([remap man]                           . consult-man)
         ([remap recentf-open-files]            . consult-recent-file) ; C-x C-r
         ([remap switch-to-buffer]              . consult-buffer)       ; C-x b
         ([remap switch-to-buffer-other-window] . consult-buffer-other-window) ; C-x 4 b
         ([remap switch-to-buffer-other-frame]  . consult-buffer-other-frame)  ; C-x 5 b
         ([remap yank-pop]                      . consult-yank-pop)     ; M-y
         ;; --- 搜索快捷键 ---
         ("M-s l"                               . consult-line)         ; Cmd+f: 当前 buffer 内搜索
         ("M-s r"                               . consult-ripgrep)      ; Cmd+r: rg 项目搜索
         ("M-s d"                               . consult-fd)           ; Cmd+d: fd 文件搜索
         ;; ("s-g"                                 . consult-goto-line)
         :map minibuffer-mode-map
         ("M-r"                                 . consult-history))     ; minibuffer 中搜索历史
  :config
  (setq consult-narrow-key "<"
        consult-async-min-input 2
        consult-async-refresh-delay 0.05)

  ;; replace multi-occur with consult-multi-occur
  (advice-add #'multi-occur :override #'consult-multi-occur)

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
             :local-repo "embark"
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
  (add-to-list 'consult-dir-sources 'consult-dir--source-tramp-ssh t)
  (add-to-list 'consult-dir-sources 'consult-dir--source-tramp-local t))

;; 覆盖 M-.（默认是 xref-find-definitions）为 embark-dwim
;; embark-dwim: "Do What I Mean" —— 根据上下文执行最合理的默认动作
(autoload 'embark-dwim "embark" nil t)
(keymap-global-set "M-." #'embark-dwim)

;;; In-buffer completion

(use-package corfu
  :straight (:files (:defaults "extensions/*.el"))
  :hook (((prog-mode conf-mode yaml-mode shell-mode eshell-mode text-mode codex-ide-session-mode) . corfu-mode)
         ((eshell-mode shell-mode) . (lambda () (setq-local corfu-auto nil)))
         (minibuffer-setup . +corfu-enable-in-minibuffer))
  :bind (:map corfu-map
              ("TAB" . corfu-complete)
              ("<tab>" . corfu-complete)
              ("S-TAB" . +corfu-move-to-minibuffer)
              ("S-<tab>" . +corfu-move-to-minibuffer)
              ("RET" . nil))
  :config
  (setq corfu-cycle t
        corfu-auto t
        corfu-auto-prefix 2
        corfu-preselect t
        corfu-preview-current nil
        corfu-auto-delay 0.1)

  (defun +corfu-move-to-minibuffer ()
    "Use Consult's minibuffer UI for the current completion-in-region table."
    (interactive)
    (pcase completion-in-region--data
      (`(,beg ,end ,table ,pred ,extras)
       (let ((completion-extra-properties extras)
             completion-cycle-threshold completion-cycling)
         (consult-completion-in-region beg end table pred)))))
  (add-to-list 'corfu-continue-commands #'corfu-move-to-minibuffer)

  (defun +corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      (corfu-mode 1))))

(use-package corfu-history
  :straight nil
  :after corfu
  :config
  (corfu-history-mode 1)
  (with-eval-after-load 'savehist
    (cl-pushnew 'corfu-history savehist-additional-variables)))

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


;; ;; cape-company-to-capf 需要 company，虽然不用 company-mode 但需作为库加载
;; (use-package company
;;   :straight t
;;   :defer t)

(use-package cape
  :straight t
  :hook (((TeX-mode LaTeX-mode org-mode markdown-mode) . +completion-add-tex-capfs))
  :init
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
