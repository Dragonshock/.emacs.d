;;; -*- lexical-binding: t; -*-

(use-package liberime
  :straight (liberime :type git :host github :repo "emacs-rime/liberime")
  :demand t
  :init
  (setq liberime-auto-build t))

(use-package rimel
  :straight (rimel :type nil
                   :local-repo "~/code/rimel")
  :after liberime
  :demand t
  :custom-face
  (rimel-candidate-label-face ((t (:inherit font-lock-comment-face :height 0.85))))
  (rimel-page-indicator-face ((t (:inherit font-lock-comment-face :height 0.85))))
  (rimel-highlight-face ((t (:inherit hl-line))))
  :init
  (setq default-input-method "rimel")
  :bind ("C-SPC" . toggle-input-method)
  :config
  (setq rimel-show-candidate 'posframe
        rimel-inline-preedit t
        rimel-candidate-show-preedit nil
        rimel-posframe-style 'horizontal
        rimel-posframe-properties nil
        rimel-candidate-label-format "%d "
        rimel-page-indicator-format "%d%s"
        rimel-disable-predicates '(rimel-predicate-prog-in-code-p
                                   rimel-predicate-after-alphabet-char-p
                                   rimel-predicate-current-uppercase-letter-p
                                   rimel-predicate-org-in-src-block-p
                                   rimel-predicate-org-latex-mode-p
                                   rimel-predicate-tex-math-or-command-p))
  )

;; [sis] automatically switch input source
(use-package sis
  :straight t
  :hook (;; Enable the inline-english-mode for all buffers.
         ;; When add space after chinese char, automatically switch to english mode
         (after-init . sis-global-inline-mode)
         ;; Enable the context-mode for all buffers
         (after-init . sis-global-context-mode)
         ;; Colored cursor
         (after-init . sis-global-cursor-color-mode))
  :config
  ;; Use rimel as default
  (sis-ism-lazyman-config nil "rimel" 'native)

  ;; HACK: Set cursor color automatically
  (add-hook! (enable-theme-functions server-after-make-frame-hook) :unless-daemonp-call-immediately
    (defun +sis-set-cursor-color (&rest _)
      (setq sis-other-cursor-color (face-foreground 'error nil t)
            sis-default-cursor-color (face-background 'cursor nil t))))

  ;; Recover the terminal cursor color when leaving Emacs (TUI only).
  (add-hook! kill-emacs-hook
    (defun +sis-reset-terminal-cursor-color ()
      (unless (display-graphic-p)
        (send-string-to-terminal "\e]112\a"))))

  (defconst +sis-chinese-puncs "，。？！；：（【「“")

  (defconst +sis-chinese-punc-chars (string-to-list +sis-chinese-puncs))

  (defun +sis-remove-head-space-after-cc-punc (_)
    (when (or (memq (char-before) +sis-chinese-punc-chars)
              (bolp))
      (delete-char 1)))
  (setq sis-inline-tighten-head-rule #'+sis-remove-head-space-after-cc-punc)

  (defun +sis-remove-tail-space-before-cc-punc (_)
    (when (eq (char-before) ? )
      (backward-delete-char 1)
      (when (and (eq (char-before) ? )
                 (memq (char-after) +sis-chinese-punc-chars))
        (backward-delete-char 1))))
  (setq sis-inline-tighten-tail-rule #'+sis-remove-tail-space-before-cc-punc)

  ;; Context mode
  (add-hook 'meow-insert-exit-hook #'sis-set-english)
  (add-to-list 'sis-context-hooks 'meow-insert-enter-hook)

  ;; Ignore some mode with context mode
  (defadvice! +sis-context-guess-ignore-modes (fn &rest args)
    :around #'sis--context-guess
    (if (derived-mode-p 'pdf-view-mode)
        'english
      (apply fn args)))

  (defun +sis-context-switching-other (back-detect fore-detect)
    (when (and meow-insert-mode
               (or (and (derived-mode-p 'org-mode 'markdown-mode 'text-mode)
                        (sis--context-other-p back-detect fore-detect))
                   (and (derived-mode-p 'telega-chat-mode)
                        (or (and (= (point) telega-chatbuf--input-marker) ; beginning of input
                                 (eolp))
                            (sis--context-other-p back-detect fore-detect)))))
      'other))

  (add-to-list 'sis-context-detectors #'+sis-context-switching-other)

  ;; Inline-mode
  (defvar-local +sis-inline-english-last-space-pos nil
    "The last space position in inline mode.")

  (add-hook! sis-inline-english-deactivated-hook
    (defun +sis-line-set-last-space-pos ()
      (when (eq (char-before) ?\s)
        (setq +sis-inline-english-last-space-pos (point)))))

  (add-hook! sis-inline-mode-hook
    (defun +sis-inline-add-post-self-insert-hook ()
      (add-hook! post-self-insert-hook :local
        (defun +sis-inline-remove-redundant-space ()
          (when (and (eq +sis-inline-english-last-space-pos (1- (point)))
                     (looking-back (concat " [" +sis-chinese-puncs "]")))
            (save-excursion
              (backward-char 2)
              (delete-char 1)
              (setq-local +sis-inline-english-last-space-pos nil))))))))
