;;; -*- lexical-binding: t -*-

;; Chinese prunc mapping
(cl-loop for prefix in '("C-" "M-" "s-" "H-")
         do
         (cl-loop for cpunc in '("，" "。" "？" "！" "；" "：" "、" "（" "）" "【" "】" "《" "》" "—")
                  for epunc in '("," "." "?" "!" ";" ":" "\\" "(" ")" "[" "]" "<" ">" "_")
                  do (define-key key-translation-map (kbd (concat prefix cpunc)) (kbd (concat prefix epunc)))))


(global-set-key (kbd "s-a") #'mark-whole-buffer)
(global-set-key (kbd "s-x") #'kill-region)
(global-set-key (kbd "s-s") #'save-buffer)
(global-set-key (kbd "s-v") #'yank)
(global-set-key (kbd "s-c") #'copy-region-as-kill)
(global-set-key (kbd "s-z") #'undo)
(global-set-key (kbd "s-Z") #'undo-redo)
(global-set-key (kbd "s-f") #'isearch-forward)
(global-set-key (kbd "s-w") #'tab-close)
(global-set-key (kbd "s-t") #'tab-new)
;; 浏览器习惯：C-<tab> / C-S-<tab> 循环切换 tab。magit（section 折叠）
;; 与 agent-shell（会话模式切换）的 mode map 各自占用 C-<tab>，
;; 在这两类 buffer 里保持其原有行为。
(global-set-key (kbd "C-<tab>") #'tab-next)
(global-set-key (kbd "C-S-<tab>") #'tab-previous)
(global-set-key (kbd "s-o") #'other-window)
(global-set-key (kbd "s-,") nil)
