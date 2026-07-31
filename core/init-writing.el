;;; -*- lexical-binding: t -*-


;; [visual-fill-column] Center text in markdown and org
(use-package visual-fill-column
  :straight t
  :hook (text-mode . visual-fill-column-mode)
  :config
  (setq-default visual-fill-column-center-text t))


;; [visual-line-mode] Soft line-wrapping
(add-hook 'text-mode-hook 'visual-line-mode)


;; [edit-indirect] Edit code blocks indirectly
(use-package edit-indirect
  :straight t)


;; [pangu] Add pangu spaces
(use-package pangu-spacing
  :straight t)

(use-package markdown-ts-mode
  :straight (:type built-in)
  :mode (("\\.md\\'" . markdown-ts-mode)
         ("\\.markdown\\'" . markdown-ts-mode))
  :config
  ;; Hide markup / inline images are buffer-local (:local t) — set defaults.
  (setq-default markdown-ts-hide-markup t
                markdown-ts-inline-images t)
  ;; Fold bodies on open, keep all heading levels visible
  (setq markdown-ts-default-folding 'fold-headings)
  ;; fontify/context/table modes already default to t in Emacs 31 markdown-ts-mode.

  ;; markdown-ts-mode gives all 6 heading levels the same face; inherit the
  ;; Org level faces instead so they differ and follow the current theme.
  (dotimes (i 6)
    (set-face-attribute (intern (format "markdown-ts-heading-%d" (1+ i))) nil
                        :inherit (intern (format "org-level-%d" (1+ i)))
                        :weight 'unspecified)))


;; [typst-ts-mode]
(use-package typst-ts-mode
  ;; Upstream migrated from SourceHut to Codeberg.
  :straight (:host codeberg :repo "meow_king/typst-ts-mode")
  :custom
  (typst-ts-watch-options "--open"))

;; [auctex]
(use-package tex
  :straight auctex
  :config
  ;; Global minor mode: bare mode symbol on a hook toggles per buffer and
  ;; can flip SyncTeX off when opening multiple TeX buffers. Enable once.
  (TeX-source-correlate-mode 1)
  (setq TeX-parse-self t             ; parse on load
        TeX-auto-save t              ; parse on save
        ;; Use hidden directories for AUCTeX files.
        TeX-auto-local ".auctex-auto"
        TeX-style-local ".auctex-style"
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
