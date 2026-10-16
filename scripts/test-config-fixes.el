;;; -*- lexical-binding: t -*-

;; Batch checks for the config fixes.  Run from the repo root:
;;   emacs -Q --batch -l scripts/test-config-fixes.el
;; Each check prints "PASS" or "FAIL".  The process exits non-zero
;; when any check fails.  Nothing here loads the running config, so it
;; does not touch the Rime database.

(defvar +test-failures nil)

(defmacro +test (name &rest body)
  `(let ((err (condition-case e
                  (progn ,@body nil)
                (error e))))
     (if err
         (progn (push ,name +test-failures)
                (princ (format "FAIL %s: %S\n" ,name err)))
       (princ (format "PASS %s\n" ,name)))))

(defconst +repo (expand-file-name ".." (file-name-directory load-file-name)))

(defun +read (relative)
  (with-temp-buffer
    (insert-file-contents (expand-file-name relative +repo))
    (buffer-string)))

(defun +load-straight-feature (feature)
  "Load FEATURE from its straight checkout without running autoloads."
  (let* ((repo (expand-file-name "straight/repos" +repo))
         (dirs (cddr (directory-files repo t))))
    (dolist (dir dirs)
      (when (file-directory-p dir)
        (dolist (file (directory-files dir t (format "\\`%s\\.el\\'" feature)))
          (let ((load-path (cons dir load-path)))
            (require feature nil t)))))))

;; ---------------------------------------------------------------- meow

(+test "no bare meow-insert-mode in loaded config"
  (dolist (file '("core/init-ime.el" "core/init-org.el"
                  "core/init-media.el" "core/init-highlight.el"))
    (let ((text (+read file)))
      (when (string-match-p "\\_<meow-insert-mode\\_>" text)
        (unless (string-match-p "bound-and-true-p meow-insert-mode" text)
          (error "%s still references meow-insert-mode bare" file)))
      (when (string-match-p "hook!? +meow-insert-e\\(xit\\|nter\\)-hook" text)
        (error "%s still hooks a meow insert state" file)))))

(+test "table realign runs from post-command-hook"
  (let* ((text (+read "core/init-org.el"))
         (start (string-match "(defun \\+org-realign-table-maybe-h" text)))
    (unless start (error "function missing"))
    (unless (string-match-p "post-command-hook" (substring text (max 0 (- start 80)) start))
      (error "not on post-command-hook"))
    (unless (string-match-p "org-table-align" (substring text start))
      (error "does not realign"))))

(+test "emms navigation is not a meow remap"
  (let ((text (+read "core/init-media.el")))
    (when (string-match-p "remap meow-" text)
      (error "still remaps meow commands"))
    (dolist (key '("\"h\"" "\"j\"" "\"k\"" "\"l\""))
      (unless (string-match-p key text)
        (error "missing direct binding %s" key)))))

(+test "symbol-overlay keeps its own keys"
  (let ((text (+read "core/init-highlight.el")))
    (dolist (key '("\"h\"" "\"q\"" "\"i\""))
      (when (string-match-p (format "(%s \\. nil)" key) text)
        (error "%s is still unbound" key)))))

;; --------------------------------------------------------------- sis

(+test "sis inline tail rule keeps one trailing space"
  (let ((text (+read "core/init-ime.el")))
    (unless (string-match-p "sis-inline-tighten-tail-rule 'one" text)
      (error "tail rule is not 'one"))
    (when (string-match-p "sis-inline-tighten-tail-rule #'\\+sis-remove-tail-space-before-cc-punc"
                          text)
      (error "tail rule deletes the trailing space again"))))

(+test "telega detector does not signal when meow is absent"
  (let ((text (+read "core/init-ime.el")))
    (unless (string-match-p "bound-and-true-p meow-insert-mode" text)
      (error "detector still reads meow-insert-mode unguarded"))))

;; --------------------------------------------------------- breadcrumb

(+test "breadcrumb settings use the expanded names"
  (let ((text (+read "core/init-modeline.el"))
        (shorthand (with-temp-buffer
                     (insert-file-contents
                      (expand-file-name "straight/repos/breadcrumb/breadcrumb.el" +repo))
                     (buffer-string))))
    (unless (string-match-p "read-symbol-shorthands: ((\"bc-\" \\. \"breadcrumb-\"))"
                            shorthand)
      (error "breadcrumb no longer expands bc- to breadcrumb-"))
    (dolist (name '("breadcrumb-imenu-crumb-separator"
                    "breadcrumb-project-max-length" "breadcrumb-idle-time"
                    "breadcrumb-project-base-face" "breadcrumb-project-leaf-face"
                    "breadcrumb-imenu-leaf-face" "breadcrumb--ipath-plain-cache"))
      (unless (string-match-p name text)
        (error "missing %s" name)))
    (when (string-match-p "\\bbc-[a-z-]*" text)
      (error "uses the bc- shorthand, which only expands inside breadcrumb.el"))))

;; ------------------------------------------------------------ diff-hl

(+test "diff-hl undo binding names a command that exists"
  (let ((text (+read "core/init-vcs.el")))
    (when (string-match-p "diff-hl-undo-revert-hunk" text)
      (error "still bound to a command this checkout does not define"))
    (unless (string-match-p "diff-hl-revert-hunk" text)
      (error "revert binding missing"))))

;; ------------------------------------------------------------ elfeed

(+test "elfeed no longer sets the obsolete clipboard variable"
  (when (string-match-p "elfeed-search-clipboard-type" (+read "core/init-elfeed.el"))
    (error "obsolete variable still set")))

;; --------------------------------------------------------- orderless

(+test "orderless keeps the default affix dispatcher"
  (let ((text (+read "core/init-completion.el")))
    (when (string-match-p "orderless-style-dispatchers '(+orderless-dispatch)" text)
      (error "custom dispatcher still replaces the default"))
    (unless (string-match-p "orderless-affix-dispatch-alist" text)
      (error "affix alist not customized"))
    (unless (string-match-p "orderless-affix-dispatch" text)
      (error "default dispatcher not kept"))))

;; ----------------------------------------------------------- vertico

(+test "vertico directory tidy is not hooked twice"
  (when (string-match-p "rfn-eshadow-update-overlay \\. vertico-directory-tidy"
                        (+read "core/init-completion.el"))
    (error "manual hook still present")))

;; ------------------------------------------------------- agent-shell

(+test "agent-shell M-RET is left to the package"
  (let ((text (+read "core/init-ai.el")))
    (when (string-match-p "agent-shell-newline" text)
      (error "M-RET still rebound to newline"))))

;; ------------------------------------------------------------ gptel

(+test "magpie model is applied buffer-locally"
  (let* ((text (+read "core/init-ai.el"))
         (start (string-match "(defun \\+gptel-magpie-apply-model" text)))
    (unless start (error "function missing"))
    (let ((fn (substring text start (+ start 500))))
      (unless (string-match-p "setq-local gptel-model" fn)
        (error "still sets the global value")))))

;; ----------------------------------------------------------- consult

(+test "consult fd source uses the pipeline directly"
  (let* ((text (+read "core/init-completion.el"))
         (start (string-match "(defvar \\+consult-source-fd" text)))
    (unless start (error "source missing"))
    (let ((src (substring text start (string-match "\n(use-package " text start))))
      (when (string-match-p ":async (lambda (sink)" src)
        (error "async still wrapped in a sink lambda"))
      (unless (string-match-p ":async (let ((consult-fd-args" src)
        (error "async is not the pipeline"))
      (unless (string-match-p "(consult--process-collection" src)
        (error "pipeline call missing"))
      (unless (string-match-p ":state[ \t]+#'consult--file-state" src)
        (error "state is not the file state constructor")))))

;; ----------------------------------------------------------- telega

(+test "telega-use-images is set before the package loads"
  (let ((text (+read "core/init-social.el")))
    (unless (string-match-p ":init[^\0]*?telega-use-images nil" text)
      (error "not set in :init"))))

;; ------------------------------------------------------- behavioral

(+test "inline overlay deactivation survives without meow"
  (+load-straight-feature 'sis)
  (unless (fboundp 'sis--inline-fly-check-deactivate)
    (error "sis did not load"))
  (defvar meow-insert-exit-hook nil)
  (defvar sis-context-hooks nil)
  (with-temp-buffer
    (setq-local sis-inline-mode t
                sis-context-mode t
                sis--for-buffer 'other
                sis--inline-lang 'english)
    (insert "abc")
    (setq-local sis--inline-overlay (make-overlay 1 (point) nil t t))
    (goto-char (point-max))
    (forward-char 0)
    (goto-char (1+ (point-max)) )
    ;; Point past the overlay, which is one of the close conditions.
    (goto-char (point-min))
    (let ((sis-context-detectors
           (list (lambda (&rest _) (and (bound-and-true-p meow-insert-mode) 'other)))))
      (setq-local post-command-hook '(sis--inline-fly-check-deactivate))
      (condition-case err
          (run-hooks 'post-command-hook)
        (error (error "hook signaled %S" err))))))

(when +test-failures
  (princ (format "\n%d failed\n" (length +test-failures)))
  (kill-emacs 1))
(princ "\nall checks passed\n")
