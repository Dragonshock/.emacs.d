;;; -*- lexical-binding: t -*-
;; [isearch] Use builtin isearch to replace `anzu'
(use-package isearch
  :bind (:map isearch-mode-map
              ([remap isearch-delete-char] . isearch-del-char))
  :config
  (setq
   ;; Record isearch in minibuffer history, so C-x ESC ESC can repeat it.
   isearch-resume-in-command-history t
   ;; One space can represent a sequence of whitespaces
   isearch-lax-whitespace t
   ;; direction change
   isearch-repeat-on-direction-change t
   ;; M-< and M-> move to the first/last occurrence of the current search string.
   isearch-allow-motion t
   isearch-motion-changes-direction t
   ;; lazy-count
   isearch-lazy-count t
   lazy-highlight-cleanup nil
   lazy-highlight-buffer t
   ;; search-ring
   search-ring-max 200
   isearch-wrap-pause t
   regexp-search-ring-max 200))


;; [ezf] Use Emacs completion from terminal shells
(use-package ezf
  :straight (:type git :host github :repo "roife/ezf")
  :commands ezf-client)


;; [goto-addr] Click to open URL
(use-package goto-addr
  :hook ((text-mode . goto-address-mode)
         (prog-mode . goto-address-prog-mode)))


;; [avy] Jump with several key strock
(use-package avy
  :straight t
  :bind (("C-, ." . avy-goto-char)
         ("C-, ," . avy-goto-char-2)
         ("C-, l" . avy-goto-line)
         :map isearch-mode-map
         ("C-, ," . avy-isearch))
  :config
  ;; overlay is used during isearch, `pre' style makes avy keys evident.
  (setq avy-styles-alist '((avy-isearch . pre))))


;; [link-hint] Open URL in text with avy
(use-package link-hint
  :straight t
  :bind
  ("C-, j" . link-hint-open-link)
  ("C-, c" . link-hint-copy-link))

(provide 'init-search)
