;;; -*- lexical-binding: t -*-
;; Langs
(use-package cc-mode
  :config
  (setq c-basic-offset 4)
  (c-set-offset 'case-label '+))


(use-package csv-mode
  :straight t)
(use-package rainbow-csv
  :straight (:host github :repo "emacs-vs/rainbow-csv"))
(use-package rmsbolt
  :straight t)
(use-package llvm-mode
  :straight (:host github :repo "nverno/llvm-mode" :files ("*.el")))
(use-package fish-mode
  :straight t)
(use-package yaml-mode
  :straight t)
(use-package toml-mode
  :straight t)
(use-package tuareg
  :straight t
  ;; Inheriting `default' would override the background of Org source blocks.
  :custom-face
  (tuareg-font-lock-constructor-face ((t (:inherit nil :background unspecified)))))


(use-package js
  :config
  (setq js-indent-level 2))


(use-package css-mode
  :config
  (setq css-indent-offset 2))


(use-package rust-mode
  :straight t
  :init
  (setq rust-mode-treesitter-derive t
        rust-format-goto-problem nil)
  :config
  (with-eval-after-load 'dtrt-indent
    (setf (alist-get 'rust-mode dtrt-indent-hook-mapping-list)
          '(c/c++/java rust-ts-indent-offset))))


(use-package rust-playground
  :straight t
  :init
  (setq rust-playground-basedir
        (no-littering-expand-var-file-name "rust-playground/"))
  (make-directory rust-playground-basedir t))


(use-package jupyter-notebook
  :straight (:type git :host github :repo "roife/jupyter.el")
  :mode ("\\.ipynb\\'" . jupyter-notebook-mode)
  :commands jupyter-notebook-new
  :custom
  (jupyter-notebook-formula-scale 2.0))


(use-package verilog-mode
  :straight (:type built-in)
  :config
  (setq verilog-align-ifelse t
        verilog-auto-delete-trailing-whitespace t
        verilog-auto-inst-param-value t
        verilog-auto-inst-vector nil
        verilog-auto-lineup 'all
        verilog-auto-newline nil
        verilog-auto-save-policy nil
        verilog-auto-template-warn-unused t
        verilog-case-indent 4
        verilog-cexp-indent 4
        verilog-highlight-grouping-keywords t
        verilog-highlight-modules t
        verilog-indent-level 4
        verilog-indent-level-behavioral 4
        verilog-indent-level-declaration 4
        verilog-indent-level-module 4
        verilog-tab-to-comment t))


;; [nix]
(use-package nix-mode
  :straight t
  :mode "\\.nix\\'")


;; [graphviz-dot]
(use-package graphviz-dot-mode
  :straight t
  :config
  (setq graphviz-dot-indent-width 4))


;; Major mode for editing web templates
(use-package web-mode
  :straight t
  :mode ("\\.[px]?html?\\'"
         "\\.\\(?:tpl\\|blade\\)\\(?:\\.php\\)?\\'"
         "\\.erb\\'"
         "\\.[lh]?eex\\'"
         "\\.jsp\\'"
         "\\.as[cp]x\\'"
         "\\.ejs\\'"
         "\\.hbs\\'"
         "\\.mustache\\'"
         "\\.svelte\\'"
         "\\.twig\\'"
         "\\.jinja2?\\'"
         "\\.eco\\'"
         "wp-content/themes/.+/.+\\.php\\'"
         "templates/.+\\.php\\'")
  :config
  (setq
   web-mode-markup-indent-offset 2
   web-mode-css-indent-offset 2
   web-mode-code-indent-offset 2
   web-mode-enable-html-entities-fontification t
   web-mode-auto-close-style 1))


;; [treesit]
(use-package treesit
  :when (treesit-available-p)
  :init
  (setq treesit-enabled-modes t
        treesit-auto-install-grammar 'always))

(provide 'init-langs)
