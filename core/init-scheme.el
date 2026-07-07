;;; init-scheme.el --- Scheme programming with Geiser -*- lexical-binding: t -*-

;;; Commentary:
;; Geiser — 通用 Scheme REPL 交互环境。
;; 支持 Guile, Racket, MIT Scheme, Chicken, Gambit, Chez 等实现。
;; SICP 学习推荐使用 Racket + #lang sicp。
;;
;; 安装 (macOS):
;;   brew install --cask racket
;;   raco pkg install sicp
;;
;; 或者:
;;   brew install mit-scheme
;;
;; References:
;;   https://geiser.nongnu.org
;;   https://docs.racket-lang.org/sicp-manual/index.html

;;; Code:

(use-package scheme-mode
  :ensure nil
  :mode "\\.scm\\'"
  :mode "\\.ss\\'"
  :init
  (setq scheme-program-name "racket")   ; 或 "mit-scheme")
  :config
  ;; SICP 代码需要 Racket 的 sicp 语言包
  ;; 在每个 .rkt 文件头部添加: #lang sicp
  )

(use-package geiser
  :straight t
  :hook (scheme-mode . geiser-mode)
  :bind (:map scheme-mode-map
              ("C-c C-z" . geiser-mode-switch-to-repl)
              ("C-c C-b" . geiser-eval-buffer)
              ("C-c C-r" . geiser-eval-region)
              ("C-c C-e" . geiser-eval-last-sexp)
              ("C-M-x"   . geiser-eval-definition)
              ("C-c C-d" . geiser-doc-symbol-at-point))
  :custom
  (geiser-active-implementations '(racket guile mit))
  (geiser-default-implementation 'racket)
  (geiser-repl-history-filename (expand-file-name "geiser-history" user-emacs-directory))
  (geiser-repl-use-other-window nil)
  (geiser-mode-start-repl-p t))

;; Racket 实现支持 — 必须单独安装，geiser 只提供框架
(use-package geiser-racket
  :straight t
  :after geiser)

(provide 'init-scheme)
