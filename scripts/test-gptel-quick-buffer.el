;;; test-gptel-quick-buffer.el --- TDD tests for gptel-quick buffer rendering -*- lexical-binding: t -*-
;;
;; Self-contained batch test for the "render into a dedicated buffer" change to
;; core/init-ai.el.  Nothing is loaded from straight/ and the full init.el is
;; never loaded: the definitions under test are located BY NAME inside the
;; (use-package gptel-quick ...) block and evaluated individually.
;;
;; Run from the repo root:
;;
;;   cd /Users/dragon/.config/emacs && emacs -Q --batch -l scripts/test-gptel-quick-buffer.el
;;
;; Exit code is 0 iff every case passes, non-zero otherwise.  Until the
;; implementation lands, the required definitions do not exist and the script
;; prints "FAIL: definition not found: <name>" for each -- that is the
;; expected TDD baseline.
;;
;; CONTRACT pinned by this file (see also
;; dev-docs/notes/gptel-render-non-popup-requirements-2026-02-11.md):
;;
;;  1. `+gptel-quick-render-function' (defvar or standalone-evaluable defcustom
;;     inside the gptel-quick block), default `buffer'.  `popup' keeps the old
;;     gptel-quick posframe path.
;;
;;  1a. The spec-mandated named helpers `+gptel-quick--buffer-name',
;;      `+gptel-quick--setup-result-buffer' and
;;      `+gptel-quick--insert-chunk' live in the same block and are
;;      extracted alongside the four core definitions: the caller and
;;      callback under test call them at replay time, so without
;;      extraction the cases would fail on void-function.
;;
;;  2. `+gptel-quick-region-or-buffer' gains a 4th optional argument ACTION (a
;;     string, e.g. "translate") naming the result buffer
;;     "*gptel-quick: <action>*".
;;     - render `popup': one call (gptel-quick QUERY nil OPTIONS), OPTIONS
;;       carrying :system SYSTEM verbatim; no direct gptel-request call.
;;     - render `buffer': one call (gptel-request QUERY :system SYSTEM
;;       :callback <callback> ...) with QUERY = the region/buffer text; the
;;       ACTION is threaded to the callback through the request itself (e.g.
;;       via gptel-request's :context key, which gptel surfaces in INFO), so
;;       a plain (response info) callback can find it.
;;
;;  3. `+gptel-quick--display-buffer-callback' is the rendering callback, driven
;;     here through whatever :callback the stubbed gptel-request captures, so
;;     a thin closure around it also works as long as it obeys gptel's
;;     callback protocol:
;;     - string chunk: insert into "*gptel-quick: <action>*" (create/reuse);
;;     - t: completion; call `+gptel-quick--show-buffer' exactly once with the
;;       result buffer OBJECT;
;;     - nil (with :error/:status in INFO): fail quietly, no error thrown;
;;     - never modifies the source buffer, never writes the kill-ring;
;;     - the result buffer's header line must mention the source buffer name;
;;     - a new round for the same action must reuse the SAME result buffer
;;       object and clear stale contents (at request time or first chunk);
;;     - the result buffer stays an ordinary, editable buffer.
;;
;;  4. `+gptel-quick--show-buffer' (BUFFER) displays the result buffer (side
;;     window, no focus steal).  Display behavior is not tested; the function
;;     is stubbed to a recorder.
;;
;;  5. Request-time code paths must depend only on stubbed externals;
;;     (require 'gptel) / (require 'gptel-quick) are satisfied by temporary
;;     stub files added to load-path (never straight/).
;;
;; Self-check affordance: GPT_QUICK_TEST_INIT_AI points this harness at a
;; synthetic file (e.g. with candidate definitions) instead of the real
;; core/init-ai.el.  The default is the real config file.

;;; Code:

(require 'cl-lib)
(require 'subr-x nil t)

(defconst +test--repo-root
  (file-name-directory
   (directory-file-name
    (file-name-directory
     (expand-file-name (or load-file-name buffer-file-name
                           "scripts/test-gptel-quick-buffer.el"))))))

(defconst +test--init-ai-file
  (or (getenv "GPT_QUICK_TEST_INIT_AI")
      (expand-file-name "core/init-ai.el" +test--repo-root)))

(defconst +test--required-defs
  '(+gptel-quick-region-or-buffer
    +gptel-quick-render-function
    +gptel-quick--buffer-name
    +gptel-quick--setup-result-buffer
    +gptel-quick--insert-chunk
    +gptel-quick--display-buffer-callback
    +gptel-quick--show-buffer)
  "Definitions that must exist inside the gptel-quick block.
The last three symbols before `+gptel-quick--display-buffer-callback'
are the implementation's named helpers (per the implementation spec);
they are extracted as well so the code under test can call them at
replay time.")

(defun +test--stub-features ()
  "Satisfy (require 'gptel) and (require 'gptel-quick) with temp stubs."
  (let ((dir (make-temp-file "gptel-quick-test-stub-" t)))
    (with-temp-file (expand-file-name "gptel.el" dir)
      (insert "; -*- lexical-binding: t -*-\n;; test stub\n(provide 'gptel)\n"))
    (with-temp-file (expand-file-name "gptel-quick.el" dir)
      (insert "; -*- lexical-binding: t -*-\n;; test stub\n(require 'gptel)\n(provide 'gptel-quick)\n"))
    (push dir load-path)))

(defvar +test--init-ai-buffer nil)

(defun +test--init-ai-buffer ()
  "Return a scratch buffer holding the contents of `+test--init-ai-file'."
  (or +test--init-ai-buffer
      (with-current-buffer (generate-new-buffer " *gptel-quick-test core*")
        (insert-file-contents +test--init-ai-file)
        (emacs-lisp-mode)
        (setq +test--init-ai-buffer (current-buffer)))))

(defun +test--block-bounds ()
  "Return (BEG . END) of the (use-package gptel-quick ...) sexp."
  (with-current-buffer (+test--init-ai-buffer)
    (save-excursion
      (goto-char (point-min))
      (re-search-forward "(use-package gptel-quick\\_>")
      (let ((beg (match-beginning 0)))
        (goto-char beg)
        (forward-sexp 1)
        (cons beg (point))))))

(defun +test--extract-def (name)
  "Locate the definition of NAME inside the gptel-quick block and evaluate it.
Return non-nil if found and evaluated; nil if NAME is not defined there."
  (let ((bounds (+test--block-bounds)))
    (with-current-buffer (+test--init-ai-buffer)
      (save-excursion
        (goto-char (car bounds))
        (when (re-search-forward
               (concat "(def\\(?:un\\|var\\|custom\\|macro\\|subst\\|const\\)\\s-+"
                       (regexp-quote (symbol-name name)) "\\_>")
               (cdr bounds) t)
          (goto-char (match-beginning 0))
          (eval (read (current-buffer)) t)
          t)))))

;; ---------------------------------------------------------------- report

(defvar +test--case nil)
(defvar +test--case-errors nil)
(defvar +test--failed-cases 0)

(defun +test--fail (fmt &rest args)
  (let ((msg (apply #'format fmt args)))
    (push msg +test--case-errors)
    (princ (format "FAIL: %s: %s\n" +test--case msg))
    nil))

(defun +test--expect (ok fmt &rest args)
  (if ok t (apply #'+test--fail fmt args)))

;; ---------------------------------------------------------------- stubs

(defvar +test--gptel-request-calls nil)
(defvar +test--gptel-quick-calls nil)
(defvar +test--show-calls nil)
(defvar +test--display-buffer-calls nil)

(defun +test--gptel-request-stub (prompt &rest keys)
  (push (cons prompt keys) +test--gptel-request-calls))

(defun +test--gptel-quick-stub (query &optional count options)
  (push (list query count options) +test--gptel-quick-calls))

(defun +test--show-buffer-stub (buffer)
  (push buffer +test--show-calls))

;; ---------------------------------------------------------------- helpers

(defconst +test--source-text "The quick brown fox jumps over the lazy dog.")
(defconst +test--system-translate "Translate into fluent Chinese.")

(defun +test--make-source ()
  "Return a fresh, read-only buffer containing `+test--source-text'."
  (let ((buf (generate-new-buffer " *gptel-quick-test source*")))
    (with-current-buffer buf
      (insert +test--source-text)
      (read-only-mode 1))
    buf))

(defun +test--cleanup ()
  (dolist (buf (buffer-list))
    (let ((name (buffer-name buf)))
      (when (and (not (eq buf +test--init-ai-buffer))
                 (or (string-prefix-p "*gptel-quick:" name)
                     (string-prefix-p " *gptel-quick-test source" name)))
        (ignore-errors (kill-buffer buf)))))
  (setq +test--gptel-request-calls nil
        +test--gptel-quick-calls nil
        +test--show-calls nil))

(defun +test--action-functions (action)
  "Return the function symbols named anywhere in a display ACTION list."
  (let (acc)
    (dolist (entry action)
      (dolist (item (if (consp entry) entry (list entry)))
        (when (functionp item)
          (push item acc))))
    (nreverse acc)))

(defun +test--fire (src system action)
  "Call `+gptel-quick-region-or-buffer' from SRC with buffer rendering.
ACTION is passed as the 4th argument.  Fails the current case unless exactly
one gptel-request call (and no gptel-quick call) was issued."
  (setq +test--gptel-request-calls nil
        +test--gptel-quick-calls nil)
  (with-current-buffer src
    (+gptel-quick-region-or-buffer system nil nil action))
  (let ((n (length +test--gptel-request-calls)))
    (+test--expect (= 1 n) "expected 1 gptel-request call, got %d" n))
  (+test--expect (null +test--gptel-quick-calls)
                 "gptel-quick called although render function is `buffer'"))

(defun +test--info-for (call src &rest overrides)
  "Build a fake gptel INFO for the callback captured in CALL.
Replays the caller-supplied :context, if any, and points :buffer at SRC.
OVERRIDES is a plist patched on top."
  (let ((info (list :buffer src :status 200))
        (ctx (plist-get (cdr call) :context)))
    (when ctx
      (plist-put info :context ctx))
    (while overrides
      (plist-put info (pop overrides) (pop overrides)))
    info))

;; ---------------------------------------------------------------- cases

(defun +test--case-1-render-buffer ()
  (let* ((+gptel-quick-render-function 'buffer)
         (kill-ring (list :+test-kill-ring-sentinel))
         (src (+test--make-source))
         (system +test--system-translate)
         before call cb info result)
    (setq before (with-current-buffer src (buffer-string)))
    (+test--fire src system "translate")
    (setq call (car +test--gptel-request-calls))
    (when call
      (+test--expect (string= (car call) before)
                     "query text is not the source buffer contents")
      (+test--expect (equal (plist-get (cdr call) :system) system)
                     ":system not passed through verbatim")
      (setq cb (plist-get (cdr call) :callback))
      (+test--expect (functionp cb) "gptel-request call has no :callback")
      (when (functionp cb)
        (setq info (+test--info-for call src))
        (funcall cb "敏捷的棕色狐狸跳过了懒狗。" info)
        (setq result (get-buffer "*gptel-quick: translate*"))
        (+test--expect (bufferp result)
                       "streaming: result buffer missing after first chunk")
        (when result
          (+test--expect
           (string-match-p "敏捷的棕色狐狸"
                           (with-current-buffer result (buffer-string)))
           "streaming: first chunk not inserted into result buffer"))
        (funcall cb t info)
        (setq result (get-buffer "*gptel-quick: translate*"))
        (when (bufferp result)
          (+test--expect
           (string-match-p "敏捷的棕色狐狸"
                           (with-current-buffer result (buffer-string)))
           "result buffer does not contain the translation after completion")
          (+test--expect
           (string-match-p (regexp-quote (buffer-name src))
                           (format "%s"
                                   (with-current-buffer result
                                     header-line-format)))
           "header-line does not mention the source buffer name")
          (+test--expect (not (with-current-buffer result buffer-read-only))
                         "result buffer must stay editable (copyable)"))))
    (+test--expect (string= before (with-current-buffer src (buffer-string)))
                   "source buffer was modified")
    (+test--expect (eq (car kill-ring) :+test-kill-ring-sentinel)
                   "kill-ring was written automatically")))

(defun +test--case-2-reuse ()
  (let* ((+gptel-quick-render-function 'buffer)
         (src (+test--make-source))
         (system +test--system-translate)
         call cb buf1 buf2)
    (+test--fire src system "translate")
    (setq call (car +test--gptel-request-calls)
          cb (plist-get (cdr call) :callback))
    (funcall cb "第一轮旧译文OLD" (+test--info-for call src))
    (funcall cb t (+test--info-for call src))
    (setq buf1 (get-buffer "*gptel-quick: translate*"))
    (+test--expect (bufferp buf1) "round 1: result buffer missing")
    (+test--fire src system "translate")
    (setq call (car +test--gptel-request-calls)
          cb (plist-get (cdr call) :callback))
    (funcall cb "第二轮新译文NEW" (+test--info-for call src))
    (funcall cb t (+test--info-for call src))
    (setq buf2 (get-buffer "*gptel-quick: translate*"))
    (+test--expect (bufferp buf2) "round 2: result buffer missing")
    (when (and buf1 buf2)
      (+test--expect (and (buffer-live-p buf1) (eq buf1 buf2))
                     "result buffer not reused (eq) across rounds")
      (with-current-buffer buf2
        (+test--expect (string-match-p "第二轮新译文NEW" (buffer-string))
                       "second round translation missing")
        (+test--expect (not (string-match-p "第一轮旧译文OLD" (buffer-string)))
                       "stale translation from first round still present")))))

(defun +test--case-3-error-path ()
  (let* ((+gptel-quick-render-function 'buffer)
         (src (+test--make-source))
         (system "Explain in clear Chinese, preserving necessary context and details.")
         call cb)
    (+test--fire src system "explain")
    (setq call (car +test--gptel-request-calls)
          cb (plist-get (cdr call) :callback))
    (+test--expect (functionp cb) "gptel-request call has no :callback")
    (when (functionp cb)
      (funcall cb nil (+test--info-for call src :status "boom" :error "boom")))
    (when (bufferp (get-buffer "*gptel-quick: explain*"))
      (princ "note: result buffer exists after failure (not asserted)\n"))
    (+test--expect (string= +test--source-text
                           (with-current-buffer src (buffer-string)))
                   "source buffer modified on failure")))

(defun +test--case-4-popup ()
  (let* ((+gptel-quick-render-function 'popup)
         (src (+test--make-source))
         (system +test--system-translate)
         call)
    (setq +test--gptel-quick-calls nil
          +test--gptel-request-calls nil)
    (with-current-buffer src
      (+gptel-quick-region-or-buffer system nil nil "translate"))
    (let ((n (length +test--gptel-quick-calls)))
      (+test--expect (= 1 n) "popup mode: expected 1 gptel-quick call, got %d" n))
    (+test--expect (null +test--gptel-request-calls)
                   "popup mode must not call gptel-request directly")
    (setq call (car +test--gptel-quick-calls))
    (when call
      (+test--expect (string= (nth 0 call) +test--source-text)
                     "popup mode: query text mismatch")
      (+test--expect (equal (plist-get (nth 2 call) :system) system)
                     "popup mode: :system not passed through"))))

(defun +test--case-5-show ()
  (let* ((+gptel-quick-render-function 'buffer)
         (src (+test--make-source))
         (system +test--system-translate)
         call cb info result)
    (+test--fire src system "translate")
    (setq call (car +test--gptel-request-calls)
          cb (plist-get (cdr call) :callback))
    (+test--expect (functionp cb) "gptel-request call has no :callback")
    (when (functionp cb)
      (setq info (+test--info-for call src :stream t))
      (setq +test--show-calls nil)
      (funcall cb "部分翻译" info)
      (+test--expect (null +test--show-calls)
                     "show-buffer should not run for a streaming chunk")
      (funcall cb t info)
      (let ((n (length +test--show-calls)))
        (+test--expect (= 1 n)
                       "expected exactly 1 show-buffer call after completion, got %d"
                       n)
        (setq result (get-buffer "*gptel-quick: translate*"))
        (when (bufferp result)
          (+test--expect
           (and (= n 1) (eq (car +test--show-calls) result))
           "show-buffer not called with the result buffer object"))))))

(defun +test--case-6-non-streaming ()
  "A non-streaming response arrives as one string and never sends `t'."
  (let* ((+gptel-quick-render-function 'buffer)
         (src (+test--make-source))
         (system +test--system-translate)
         call cb)
    (+test--fire src system "translate")
    (setq call (car +test--gptel-request-calls)
          cb (plist-get (cdr call) :callback))
    (+test--expect (functionp cb) "gptel-request call has no :callback")
    (when (functionp cb)
      (setq +test--show-calls nil)
      (funcall cb "完整译文" (+test--info-for call src :stream nil))
      (let ((n (length +test--show-calls)))
        (+test--expect (= 1 n)
                       "non-streaming response should show the buffer once, got %d show calls"
                       n))
      (let ((result (get-buffer "*gptel-quick: translate*")))
        (+test--expect (and (bufferp result)
                            (string-match-p "完整译文"
                                            (with-current-buffer result (buffer-string))))
                       "non-streaming response text missing from result buffer")))))

(defun +test--case-7-split-direction ()
  "The real `+gptel-quick--show-buffer' must leave the split direction open.

`display-buffer-pop-up-window' lets `split-window-sensibly' pick
left-right or top-bottom from the window size (`split-window-preferred-direction'
is `longest' by default in Emacs 31); `display-buffer-below-selected' would
force a top-bottom split on every frame."
  (let ((buf (generate-new-buffer " *gptel-quick-test target*"))
        action funcs)
    (unwind-protect
        (progn
          ;; Re-evaluate the real definition over the recorder stub installed
          ;; by the driver, so this case inspects the actual display action.
          (+test--expect (+test--extract-def '+gptel-quick--show-buffer)
                         "could not re-evaluate +gptel-quick--show-buffer")
          (setq +test--display-buffer-calls nil)
          (cl-letf (((symbol-function 'display-buffer)
                     (lambda (buffer &optional action &rest _)
                       (push (list buffer action) +test--display-buffer-calls)
                       nil)))
            (funcall '+gptel-quick--show-buffer buf))
          (let ((n (length +test--display-buffer-calls)))
            (+test--expect (= 1 n)
                           "expected exactly 1 display-buffer call, got %d" n))
          (setq action (nth 1 (car +test--display-buffer-calls)))
          (setq funcs (+test--action-functions action))
          (+test--expect (and (= 1 (length +test--display-buffer-calls))
                              (eq (car (car +test--display-buffer-calls)) buf))
                         "display-buffer not called with the result buffer")
          (+test--expect (memq 'display-buffer-pop-up-window funcs)
                         "display action lacks display-buffer-pop-up-window (got %S)"
                         action)
          (+test--expect (not (memq 'display-buffer-below-selected funcs))
                         "display action still forces display-buffer-below-selected (got %S)"
                         action)
          (+test--expect (memq 'display-buffer-reuse-window funcs)
                         "display action dropped display-buffer-reuse-window (got %S)"
                         action)
          (+test--expect (and (consp action) (consp (car action))
                              (cl-every #'functionp (car action)))
                         "display action is not a list whose car is a list of functions (got %S)"
                         action))
      (kill-buffer buf)
      ;; Restore the stub the driver installed for the other cases.
      (defalias '+gptel-quick--show-buffer #'+test--show-buffer-stub)
      (setq +test--display-buffer-calls nil))))

;; ---------------------------------------------------------------- runner

(defun +test--run-case (label fn)
  (let ((+test--case label)
        (+test--case-errors nil))
    (condition-case err
        (funcall fn)
      (error (+test--fail "uncaught error: %s" (error-message-string err))))
    (if +test--case-errors
        (cl-incf +test--failed-cases)
      (princ (format "PASS: %s\n" label)))
    (+test--cleanup)))

(defun +test--run-all ()
  (let ((cases
         '(("case 1: render=buffer (system passthrough, result buffer, header, source intact)" .
            +test--case-1-render-buffer)
           ("case 2: buffer reuse (clear and rewrite)" . +test--case-2-reuse)
           ("case 3: error path" . +test--case-3-error-path)
           ("case 4: popup fallback" . +test--case-4-popup)
           ("case 5: completion display" . +test--case-5-show)
           ("case 6: non-streaming response" . +test--case-6-non-streaming)
           ("case 7: sensible split direction" . +test--case-7-split-direction))))
    (dolist (case cases)
      (+test--run-case (car case) (symbol-function (cdr case))))
    (if (zerop +test--failed-cases)
        (progn
          (princ (format "RESULT: all %d cases passed\n" (length cases)))
          (kill-emacs 0))
      (princ (format "RESULT: %d of %d cases failed\n"
                     +test--failed-cases (length cases)))
      (kill-emacs 1))))

;; ---------------------------------------------------------------- driver

(princ (format "test file: %s\n"
               (expand-file-name (or load-file-name "scripts/test-gptel-quick-buffer.el")
                                 (or default-directory "."))))
(princ "command: cd /Users/dragon/.config/emacs && emacs -Q --batch -l scripts/test-gptel-quick-buffer.el\n")
(princ (format "target: %s\n" +test--init-ai-file))

(let ((missing 0))
  (condition-case err
      (progn
        (+test--stub-features)
        (dolist (name +test--required-defs)
          (if (+test--extract-def name)
              (princ (format "PASS: definition found: %s\n" name))
            (cl-incf missing)
            (princ (format "FAIL: definition not found: %s\n" name)))))
    (error
     (princ (format "FAIL: %s\n" (error-message-string err)))
     (kill-emacs 1)))
  (if (> missing 0)
      (progn
        (princ (format
                "RESULT: %d of %d required definitions missing; test cases skipped\n"
                missing (length +test--required-defs)))
        (kill-emacs 1))
    ;; Stub installation happens AFTER extraction so the extracted
    ;; `+gptel-quick--show-buffer' does not clobber the recorder stub.
    (defalias 'gptel-request #'+test--gptel-request-stub)
    (defalias 'gptel-quick #'+test--gptel-quick-stub)
    (defalias '+gptel-quick--show-buffer #'+test--show-buffer-stub)
    (+test--run-all)))

;;; test-gptel-quick-buffer.el ends here
