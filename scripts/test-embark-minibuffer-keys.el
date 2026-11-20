;;; -*- lexical-binding: t -*-

;; 校验 core/init-completion.el 中 `use-package embark' 的 :bind 结构。
;; 不加载完整 init.el：只读取该文件里的表单并做静态断言。
;; 运行：cd ~/.config/emacs && emacs -Q --batch -l scripts/test-embark-minibuffer-keys.el

(require 'cl-lib)
(require 'subr-x)

(defvar +test--failures 0)
(defvar +test--checks 0)

(defun +test--root ()
  "Return the repository root, inferred from this file's location."
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (or load-file-name buffer-file-name
         (expand-file-name "scripts/test-embark-minibuffer-keys.el"))))))

(defvar +test--config
  (expand-file-name "core/init-completion.el" (+test--root)))

(defun +test--expect (condition fmt &rest args)
  "Count a check; print PASS when CONDITION holds, else FAIL with FMT."
  (cl-incf +test--checks)
  (if condition
      (princ (format "PASS: %s\n" (apply #'format fmt args)))
    (cl-incf +test--failures)
    (princ (format "FAIL: %s\n" (apply #'format fmt args)))))

(defun +test--embark-bind ()
  "Return the :bind value of the `(use-package embark ...)' form."
  (with-temp-buffer
    (insert-file-contents +test--config)
    (goto-char (point-min))
    (unless (re-search-forward "^(use-package embark\\_>" nil t)
      (error "use-package embark form not found in %s" +test--config))
    (let* ((form (save-excursion
                   (goto-char (match-beginning 0))
                   (read (current-buffer))))
           (bind (plist-get (cddr form) :bind)))
      (unless bind
        (error "use-package embark has no :bind value"))
      bind)))

(defun +test--triples (bind)
  "Flatten BIND into (MAP KEY COMMAND) triples.
A `:map' item switches the target map for the bindings that follow;
bindings before the first `:map' belong to `global-map'."
  (let ((map 'global-map) (expect-map nil) (out nil))
    (dolist (item bind)
      (cond
       (expect-map
        (setq map item expect-map nil))
       ((eq item :map)
        (setq expect-map t))
       ((consp item)
        (push (list map (car item) (cdr item)) out))))
    (nreverse out)))

(defun +test--has (triples map key command)
  "Non-nil when TRIPLES contains MAP's KEY bound to COMMAND."
  (member (list map key command) triples))

(defun +test--has-key (triples map key)
  "Non-nil when TRIPLES binds KEY in MAP to anything."
  (cl-some (lambda (triple) (and (eq (nth 0 triple) map)
                                 (equal (nth 1 triple) key)))
           triples))

;; ---------------------------------------------------------------- driver

(princ (format "config: %s\n" +test--config))
(princ "command: cd ~/.config/emacs && emacs -Q --batch -l scripts/test-embark-minibuffer-keys.el\n")

(let* ((bind (condition-case err
                 (+test--embark-bind)
               (error
                (princ (format "FAIL: %s\n" (error-message-string err)))
                (kill-emacs 1))))
       (triples (+test--triples bind)))

  ;; 1-2. minibuffer 键位
  (+test--expect (+test--has triples 'minibuffer-local-map "C-c C-c" 'embark-collect)
                 "minibuffer-local-map: C-c C-c -> embark-collect")
  (+test--expect (+test--has triples 'minibuffer-local-map "C-c C-e" 'embark-export)
                 "minibuffer-local-map: C-c C-e -> embark-export")

  ;; 3-4. 不污染全局
  (+test--expect (not (+test--has-key triples 'global-map "C-c C-c"))
                 "global-map: C-c C-c must stay unbound")
  (+test--expect (not (+test--has-key triples 'global-map "C-c C-e"))
                 "global-map: C-c C-e must stay unbound")

  ;; 5. 既有全局绑定不变
  (dolist (pair '(("C-;" . embark-act)
                  ("M-;" . embark-dwim)
                  ("C-h E" . embark-bindings)))
    (+test--expect (+test--has triples 'global-map (car pair) (cdr pair))
                   "global-map: %s -> %s preserved" (car pair) (cdr pair)))

  ;; 6. 不落到 embark-file-map
  (+test--expect (not (+test--has-key triples 'embark-file-map "C-c C-c"))
                 "embark-file-map: C-c C-c must stay unbound")
  (+test--expect (not (+test--has-key triples 'embark-file-map "C-c C-e"))
                 "embark-file-map: C-c C-e must stay unbound")

  ;; 7. 既有 embark-file-map 绑定不变
  (+test--expect (+test--has triples 'embark-file-map "s" 'sudo-edit)
                 "embark-file-map: s -> sudo-edit preserved")
  (+test--expect (+test--has triples 'embark-file-map "g" '+embark-magit-status)
                 "embark-file-map: g -> +embark-magit-status preserved"))

(if (zerop +test--failures)
    (progn
      (princ (format "RESULT: all %d checks passed\n" +test--checks))
      (kill-emacs 0))
  (princ (format "RESULT: %d of %d checks failed\n"
                 +test--failures +test--checks))
  (kill-emacs 1))

;;; test-embark-minibuffer-keys.el ends here
