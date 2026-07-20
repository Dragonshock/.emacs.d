;;; init-org.el --- Org mode configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Org mode with LaTeX preview, prettify-symbols, org-modern,
;; org-appear, org-pomodoro, custom entities, and export settings.

;;; Code:

;; [org-fragtog] Preview and edit latex in md/org elegantly
;; (use-package org-fragtog
;;   :straight t
;;   :hook ((org-mode . org-fragtog-mode)))

;; [org]
(use-package org
  :straight (:type built-in)
  :init
  ;; Load optional Org modules only when explicitly enabled.
  (setq org-modules nil)
  :custom-face (org-quote ((t (:inherit org-block-begin-line))))
  :hook ((org-mode . (lambda () (setq-local dabbrev-abbrev-skip-leading-regexp "[=*]")))  ;; Skipping leading char, so corfu can complete with dabbrev for formatted text
         (org-mode . (lambda ()
                       (push '("\\operatorname{\\mathrm{" . (?  (Bc . Bl) ?{ (Bc . Br) ?{)) prettify-symbols-alist)
                       (push '("\\mathcal{" . (?  (Bc . Bl) ?{ (Bc . Br) ?𝒞)) prettify-symbols-alist)
                       (push '("\\mathbb{" . (?  (Bc . Bl) ?{ (Bc . Br) ?𝔹)) prettify-symbols-alist)
                       (push '("\\\\{" . ?{) prettify-symbols-alist)
                       (push '("\\\\}" . ?}) prettify-symbols-alist)
                       (push '("\\vec{" . (?  (Bc . Bl) ?{ (Bc . Br) ?⃗)) prettify-symbols-alist)
                       (push '("\\ " . ?‿) prettify-symbols-alist)
                       ;;     (push '("\\(" . ?‹) prettify-symbols-alist)
                       ;;           (push '("\\)" . ?›) prettify-symbols-alist)
                       ;;     (push '("\\)，" . (?  (Bc . Bl) ?， (Bc . Br) ?›)) prettify-symbols-alist)
                       ;; (push '("\\)。" . (?  (Bc . Bl) ?。 (Bc . Br) ?›)) prettify-symbols-alist)
                       ;; (push '("\\)；" . (?  (Bc . Bl) ?； (Bc . Br) ?›)) prettify-symbols-alist)
                       ;; (push '("\\[" . ?«) prettify-symbols-alist)
                       ;; (push '("\\]" . ?») prettify-symbols-alist)
                       (prettify-symbols-mode))))
  :config
  (setq
   ;; subscription: Use {} for sub- or super- scripts
   org-use-sub-superscripts '{}
   org-export-with-sub-superscripts '{}

   ;; prettify
   org-startup-indented t
   org-pretty-entities t
   org-hide-emphasis-markers t    ; 隐藏 *bold* /italic/ 等标记符号
   org-ellipsis "…"
   ;; Highlight quote and verse blocks
   org-fontify-quote-and-verse-blocks t
   ;; Highlight the whole line for headings
   org-fontify-whole-heading-line t

   ;; Edit settings
   org-auto-align-tags nil
   org-tags-column 0
   org-insert-heading-respect-content t

   ;; better keybindings
   org-special-ctrl-a/e t
   org-special-ctrl-k t
   org-special-ctrl-o t
   org-support-shift-select t
   org-ctrl-k-protect-subtree 'error
   org-fold-catch-invisible-edits 'show-and-error

   org-imenu-depth 4)

  ;; Better Org Latex Preview
  (setq org-preview-latex-default-process 'dvisvgm
        org-startup-with-latex-preview nil
        org-highlight-latex-and-related '(latex))
  (plist-put org-format-latex-options :scale 1.7)

  ;; HACK: inline highlight for CJK
  (setq org-emphasis-regexp-components '("-[:space:]('\"{[:nonascii:][:alpha:]"
                                         "-[:space:].,:!?;'\")}\\[[:nonascii:][:alpha:]"
                                         "[:space:]"
                                         "."
                                         1))
  (org-set-emph-re 'org-emphasis-regexp-components org-emphasis-regexp-components)
  (org-element-update-syntax)
  (org-element--set-regexps)
  )


;; [org-entities]
(use-package org-entities
  :config
  (setq org-entities-user
        '(("vdash" "\\vdash" t "⊢" "⊢" "⊢" "⊢")
          ("vDash" "\\vDash" t "⊨" "⊨" "⊨" "⊨")
          ("Vdash" "\\Vdash" t "⊩" "⊩" "⊩" "⊩")
          ("Vvdash" "\\Vvdash" t "⊪" "⊪" "⊪" "⊪")
          ("nvdash" "\\nvdash" t "⊬" "⊬" "⊬" "⊬")
          ("nvDash" "\\nvDash" t "⊭" "⊭" "⊭" "⊭")
          ("nVdash" "\\nVdash" t "⊮" "⊮" "⊮" "⊮")
          ("nVDash" "\\nVDash" t "⊯" "⊯" "⊯" "⊯")
          ("subseteq" "\\subseteq" t "⊆" "⊆" "⊆" "⊆")
          ("supseteq" "\\supseteq" t "⊇" "⊇" "⊇" "⊇")
          ("subsetneq" "\\subsetneq" t "⊊" "⊊" "⊊" "⊊")
          ("supsetneq" "\\supsetneq" t "⊋" "⊋" "⊋" "⊋")
          ("nsubseteq" "\\nsubseteq" t "⊈" "⊈" "⊈" "⊈")
          ("nsupseteq" "\\nsupseteq" t "⊉" "⊉" "⊉" "⊉")
          ("nsubseteqq" "\\nsubseteqq" t "⊈" "⊈" "⊈" "⊈")
          ("nsupseteqq" "\\nsupseteqq" t "⊉" "⊉" "⊉" "⊉")
          ("subsetneqq" "\\subsetneqq" t "⊊" "⊊" "⊊" "⊊")
          ("supsetneqq" "\\supsetneqq" t "⊋" "⊋" "⊋" "⊋")
          ("nsubset" "\\nsubset" t "⊄" "⊄" "⊄" "⊄")
          ("nsupset" "\\nsupset" t "⊅" "⊅" "⊅" "⊅")
          ("nsubseteq" "\\nsubseteq" t "⊈" "⊈" "⊈" "⊈")
          ("nsupseteq" "\\nsupseteq" t "⊉" "⊉" "⊉" "⊉"))))


;; [org-appear] Make invisible parts of Org elements appear visible.
(use-package org-appear
  :straight t
  :hook ((org-mode . org-appear-mode))
  :config
  (setq
   ;; org-hide-emphasis-markers t

   org-appear-autosubmarkers t
   org-appear-autoentities t
   org-appear-autokeywords t
   org-appear-inside-latex t

   org-appear-delay 0.1

   org-appear-trigger 'always)          ; manual

  (add-hook! org-mode-hook :call-immediately
    (defun +org-add-appear-hook ()
      (add-hook 'meow-insert-enter-hook #'org-appear-manual-start nil t)
      (add-hook 'meow-insert-exit-hook #'org-appear-manual-stop nil t))))


(use-package org-modern
  :straight t
  :after org
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda-mode))
  :config
  (setq org-modern-table nil)
  (setq org-modern-checkbox
        '((?X . "☑")
          (?- . "☒")
          (?\s . "□")))
  ;; 修复字体大小：默认 height 0.8 导致偏小；换用 fixed-pitch-serif
  (set-face-attribute 'org-modern-label nil :inherit 'fixed-pitch :height 0.8 :width 'normal)
  (set-face-attribute 'org-modern-block-name nil :inherit 'fixed-pitch :height 0.8 :weight 'regular))


;; [valign] 像素级对齐 Org 表格，完美解决中英文混排错位
(use-package valign
  :straight t
  :hook ((org-mode . valign-mode)
         (org-agenda-finalize . valign-mode))
  :config
  ;; 允许在 valign 模式下使用 org-table 的 TAB 等快捷键
  (setq valign-fancy-bar t))


(use-package org-modern-indent
  :straight (org-modern-indent :type git :host github :repo "jdtsmith/org-modern-indent")
  :config
  (add-hook 'org-mode-hook #'org-modern-indent-mode 90))


;; [ox]
(use-package ox
  :config
  (setq org-export-with-smart-quotes t
        org-html-validation-link nil
        org-latex-prefer-user-labels t
        org-export-with-latex t))

(provide 'init-org)
;;; init-org.el ends here
