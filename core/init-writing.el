;;; -*- lexical-binding: t -*-


;; [visual-line-mode] Soft line-wrapping (also covers markdown via text-mode)
(add-hook 'text-mode-hook #'visual-line-mode)


;; [visual-fill-column] Center a readable column for long prose (Grok plans,
;; research notes, ADRs). Keep off generic text-mode so commit messages etc.
;; stay full-width.
(use-package visual-fill-column
  :straight t
  :hook ((markdown-mode org-mode) . visual-fill-column-mode)
  :init
  (setq-default visual-fill-column-center-text t
                visual-fill-column-width 92))


;; [edit-indirect] Edit code blocks indirectly
(use-package edit-indirect
  :straight t)


;; [pangu] Add pangu spaces (on-demand; not auto-hooked)
(use-package pangu-spacing
  :straight t)


;; [markdown-mode] Reading-first GFM for Grok Build / docs output.
;; Emacs 30 has no built-in markdown-ts-mode (arrives in 31). Classic
;; markdown-mode keeps hide-markup, header scaling, native code blocks.
(use-package markdown-mode
  :straight t
  :mode (("\\.md\\'" . gfm-mode)
         ("\\.markdown\\'" . gfm-mode))
  :init
  (setq
   ;; Display: org-like reading surface
   markdown-fontify-code-blocks-natively t
   markdown-fontify-whole-heading-line t
   markdown-header-scaling t
   ;; Milder than default-org-ish 1.8…; better for long agent reports
   markdown-header-scaling-values '(1.55 1.35 1.2 1.1 1.05 1.0)
   markdown-hide-markup t
   markdown-hide-urls t
   markdown-list-indent-width 2
   ;; GFM task lists in plans / checklists
   markdown-make-gfm-checkboxes-buttons t
   ;; Unknown fences still get a sensible fallback
   markdown-fontify-code-block-default-mode 'fundamental-mode
   ;; View modes always hide markup
   markdown-hide-markup-in-view-modes t)
  :config
  (when (executable-find "pandoc")
    (setq markdown-command "pandoc"))

  (defun +markdown-toggle-view ()
    "Toggle between editable GFM and read-only `gfm-view-mode'.
In view mode: SPC/DEL scroll, n/p headings, q quit buffer, ? help.
Also bound to \\`e' in view mode (enter edit)."
    (interactive)
    (cond
     ((derived-mode-p 'gfm-view-mode)
      (gfm-mode)
      (read-only-mode -1)
      (message "Markdown: edit mode"))
     ((derived-mode-p 'markdown-view-mode)
      (markdown-mode)
      (read-only-mode -1)
      (message "Markdown: edit mode"))
     ((derived-mode-p 'gfm-mode)
      (gfm-view-mode)
      (message "Markdown: view mode (SPC/n/p/q, e edit)"))
     (t
      (markdown-view-mode)
      (message "Markdown: view mode (SPC/n/p/q, e edit)"))))

  ;; Edit map + view map (gfm-view shares markdown-view-mode-map)
  (define-key markdown-mode-map (kbd "C-c C-x C-v") #'+markdown-toggle-view)
  (define-key markdown-view-mode-map (kbd "C-c C-x C-v") #'+markdown-toggle-view)
  (define-key markdown-view-mode-map (kbd "e") #'+markdown-toggle-view))


;; [typst-ts-mode]
(use-package typst-ts-mode
  :straight (:host sourcehut :repo "meow_king/typst-ts-mode")
  :custom
  (typst-ts-mode-watch-options "--open"))

;; [auctex]
(use-package tex
  :straight auctex
  :config
  (setq TeX-parse-self t             ; parse on load
        TeX-auto-save t              ; parse on save
        ;; Use hidden directories for AUCTeX files.
        TeX-auto-local ".auctex-auto"
        TeX-style-local ".auctex-style"
        TeX-source-correlate-mode t
        TeX-source-correlate-method 'synctex
        ;; Don't start the Emacs server when correlating sources.
        TeX-source-correlate-start-server nil
        ;; Automatically insert braces after sub/superscript in `LaTeX-math-mode'.
        TeX-electric-sub-and-superscript t
        ;; Just save, don't ask before each compilation.
        TeX-save-query nil))


;; [cdlatex]
(use-package cdlatex
  :straight t)


;; [reftex]
(use-package reftex
  :straight t)
