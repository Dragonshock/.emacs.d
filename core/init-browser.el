;;; -*- lexical-binding: t -*-

;; [browse-url] Pass a URL to browser
(use-package browse-url
  :defines dired-mode-map
  :bind (("C-, o" . browse-url-at-point)
         ("C-, e" . browse-url-emacs))
  :config
  (setq browse-url-browser-function #'eww-browse-url))

;; [eww] Builtin browser
(use-package eww
  :config
  (setq shr-max-image-proportion 0.5))

(use-package xwidget
  :config
  (setq xwidget-webkit-buffer-name-format "*XWidget: %T*"))
