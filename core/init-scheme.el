;;; init-scheme.el --- Scheme / SICP with Geiser -*- lexical-binding: t -*-

;;; Commentary:
;; Geiser — Scheme REPL 交互环境。
;; SICP 主路径：Racket + #lang sicp
;; 备选实现：MIT/GNU Scheme（原书风格）
;;
;; 系统依赖 (macOS):
;;   brew install --cask racket   # 或 brew install racket
;;   raco pkg install sicp
;;   brew install mit-scheme      # 可选
;;
;; 学习工作流:
;;   1. 打开 ch1/ex-1.16.rkt，文件头写 #lang sicp
;;   2. M-x run-geiser → racket（或打开文件后自动起 REPL）
;;   3. C-c C-a 进入当前模块；C-c C-b 求值 buffer
;;
;; References:
;;   https://geiser.nongnu.org
;;   https://docs.racket-lang.org/sicp-manual/index.html

;;; Code:

;;;; ---------------------------------------------------------------------------
;;;; scheme-mode：编辑 .scm / .ss / .rkt
;;;; ---------------------------------------------------------------------------

(use-package scheme
  :ensure nil
  :mode (("\\.scm\\'" . scheme-mode)
         ("\\.ss\\'"  . scheme-mode)
         ("\\.rkt\\'" . scheme-mode))
  :init
  ;; run-scheme 回退（多数情况用 Geiser，不必依赖此变量）
  (setq scheme-program-name "racket")
  :config
  ;; SICP / Racket 常见缩进
  (put 'module 'scheme-indent-function 2)
  (put 'with-handlers 'scheme-indent-function 1)
  (put 'match 'scheme-indent-function 1)
  (put 'match-lambda 'scheme-indent-function 0)
  (put 'match-let 'scheme-indent-function 1)
  (put 'match-let* 'scheme-indent-function 1)
  (put 'syntax-case 'scheme-indent-function 2)
  (put 'syntax-rules 'scheme-indent-function 1)
  (put 'receive 'scheme-indent-function 2)
  (put 'and-let* 'scheme-indent-function 1))

;;;; ---------------------------------------------------------------------------
;;;; Geiser 核心
;;;; ---------------------------------------------------------------------------

(use-package geiser
  :straight t
  :hook (scheme-mode . geiser-mode)
  :bind (:map scheme-mode-map
              ;; 求值（与 Geiser 默认一致，显式写出便于查找）
              ("C-c C-b" . geiser-eval-buffer)
              ("C-c C-r" . geiser-eval-region)
              ("C-c C-c" . geiser-eval-definition)
              ("C-M-x"   . geiser-eval-definition)
              ("C-x C-e" . geiser-eval-last-sexp)
              ;; 加载 / REPL
              ("C-c C-l" . geiser-load-file)
              ("C-c C-z" . geiser-mode-switch-to-repl)
              ;; #lang sicp 模块：进入当前文件对应 module（最常用）
              ("C-c C-a" . geiser-mode-switch-to-repl-and-enter)
              ("C-c C-s" . geiser-set-scheme))
  :custom
  ;; 只启用本机已装的实现（避免选到 guile 报错）
  (geiser-active-implementations '(racket mit))
  (geiser-default-implementation 'racket)
  ;; 打开 scheme 文件时自动起 REPL，适合学习
  (geiser-mode-start-repl-p t)
  ;; REPL 开在另一窗口，代码与交互并排
  (geiser-repl-use-other-window t)
  (geiser-repl-history-filename
   (expand-file-name "geiser-history" user-emacs-directory))
  (geiser-repl-query-on-kill-p nil)
  (geiser-mode-autodoc-p t)
  :config
  ;; 按扩展名固定实现，避免每次询问
  (setq geiser-implementations-alist
        '(((regexp "\\.rkt\\'") racket)
          ((regexp "\\.scm\\'") racket)
          ((regexp "\\.ss\\'")  racket))))

;;;; ---------------------------------------------------------------------------
;;;; Racket（SICP 主路径）
;;;; ---------------------------------------------------------------------------

(use-package geiser-racket
  :straight t
  :after geiser
  :demand t
  :custom
  (geiser-racket-binary
   (or (executable-find "racket")
       "/opt/homebrew/bin/racket"
       "racket"))
  :config
  ;; 确保 .rkt 即使用户未先 require geiser 也能进 scheme-mode
  (add-to-list 'auto-mode-alist '("\\.rkt\\'" . scheme-mode)))

;;;; ---------------------------------------------------------------------------
;;;; MIT Scheme（备选，原书风格）
;;;; ---------------------------------------------------------------------------

(use-package geiser-mit
  :straight t
  :after geiser
  :custom
  (geiser-mit-binary
   (or (executable-find "mit-scheme")
       (executable-find "scheme")
       "mit-scheme")))

;;;; ---------------------------------------------------------------------------
;;;; SICP 小工具
;;;; ---------------------------------------------------------------------------

(defun +scheme/sicp-insert-lang-header ()
  "在 buffer 开头插入 #lang sicp（若尚未存在）。"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at-p "#lang\\s-+sicp")
      (insert "#lang sicp\n\n"))))

(defun +scheme/sicp-new-exercise (chapter number)
  "新建 SICP 练习文件 chCHAPTER/ex-CHAPTER.NUMBER.rkt 并插入模板。"
  (interactive "nChapter: \nsExercise (e.g. 1.16): ")
  (let* ((num (string-trim number))
         (dir (expand-file-name
               (format "ch%d" chapter)
               (or (locate-dominating-file default-directory "SICP-学习指南.org")
                   (expand-file-name "~/Desktop/sicp"))))
         (file (expand-file-name (format "ex-%s.rkt" num) dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    (find-file file)
    (when (zerop (buffer-size))
      (insert (format "#lang sicp\n\n;; SICP Exercise %s\n\n" num))
      (save-buffer))
    (message "Opened %s" file)))

(with-eval-after-load 'scheme
  (define-key scheme-mode-map (kbd "C-c C-t") #'+scheme/sicp-insert-lang-header)
  (define-key scheme-mode-map (kbd "C-c C-n") #'+scheme/sicp-new-exercise))

(provide 'init-scheme)
;;; init-scheme.el ends here
