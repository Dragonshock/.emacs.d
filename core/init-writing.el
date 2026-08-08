;;; -*- lexical-binding: t -*-


;; [visual-fill-column] Center text in prose modes only.
;; Do not hook bare text-mode: yaml-ts-mode / toml-ts-mode derive text-mode and
;; would get column-centered soft-wrap under treesit remaps.
(use-package visual-fill-column
  :straight t
  :hook ((org-mode markdown-ts-mode text-mode) . +maybe-visual-fill-column)
  :init
  (defun +maybe-visual-fill-column ()
    "Enable visual-fill-column for prose; skip treesit data languages."
    (unless (derived-mode-p 'yaml-ts-mode 'toml-ts-mode 'yaml-mode 'conf-mode
                            'conf-toml-mode)
      (visual-fill-column-mode 1)))
  :config
  (setq-default visual-fill-column-center-text t))


;; [visual-line-mode] Soft line-wrapping for prose only (same exclusions).
(defun +maybe-visual-line-mode ()
  "Enable `visual-line-mode' for prose; skip yaml/toml conf modes."
  (unless (derived-mode-p 'yaml-ts-mode 'toml-ts-mode 'yaml-mode 'conf-mode
                          'conf-toml-mode)
    (visual-line-mode 1)))
(add-hook 'text-mode-hook #'+maybe-visual-line-mode)


;; [edit-indirect] Edit code blocks indirectly
(use-package edit-indirect
  :straight t)

;; [pangu] Add pangu spaces
(use-package pangu-spacing
  :straight t
  :hook ((org-mode markdown-ts-mode) . pangu-spacing-mode)
  ;; pangu-spacing-real-insert-separtor defaults to nil (overlay-only) — no setq.
  )

;; [valign] Pixel-perfect visual alignment for Org/Markdown tables (GUI).
;; Overlays only — does not touch fonts/fontset. Text-based alignment left intact.
;; Org: org-modern-table is disabled in init-org.el so table display is not
;; contested; other org-modern prettifications stay enabled.
(use-package valign
  :straight t
  :hook ((org-mode . valign-mode)
         (markdown-ts-mode . valign-mode)
         ;; classic markdown-mode if ever used without treesit remap
         (markdown-mode . valign-mode))
  :config
  ;; Thinner visual bars on org/markdown pipe tables.
  (setq valign-fancy-bar t)
  ;; Keep default valign-max-table-size (4000 chars); large tables are laggy.
  )

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
  ;; Upstream migrated from SourceHut to Codeberg (local checkout re-pointed).
  :straight (:host codeberg :repo "meow_king/typst-ts-mode")
  :custom
  ;; 0.12+: list of CLI args (was a string on 0.10 SourceHut).
  (typst-ts-watch-options '("--open")))

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
  :straight t
  :hook ((LaTeX-mode . turn-on-cdlatex)
         (latex-mode . turn-on-cdlatex)))


;; [reftex]
(use-package reftex
  :straight t
  :hook ((LaTeX-mode . turn-on-reftex)
         (latex-mode . turn-on-reftex))
  :config
  (setq reftex-plug-into-AUCTeX t))
