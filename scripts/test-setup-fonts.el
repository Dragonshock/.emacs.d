;;; -*- lexical-binding: t -*-

;; Batch checks for +setup-fonts.  Run from the repo root:
;;   emacs -Q --batch -l scripts/test-setup-fonts.el
;; Does not load init.el, so it does not touch the Rime database.

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

(load (expand-file-name "core/init-util.el" +repo) nil t)

(defvar +font-calls nil)
(defvar +graphic nil)
(defvar +defined-faces nil)

(defun +record-font-call (fn &rest args)
  (push (cons fn args) +font-calls)
  nil)

(advice-add 'set-face-attribute :override
            (lambda (&rest args) (apply #'+record-font-call 'set-face-attribute args)))
(advice-add 'set-face-font :override
            (lambda (&rest args) (apply #'+record-font-call 'set-face-font args)))
(advice-add 'set-fontset-font :override
            (lambda (&rest args) (apply #'+record-font-call 'set-fontset-font args)))
(advice-add 'display-graphic-p :override (lambda (&rest _) +graphic))
(advice-add 'facep :override (lambda (face) (memq face +defined-faces)))
(defvar +available-font-families '("PragmataPro" "Apple Symbols" "Apple Color Emoji"))
(advice-add 'find-font :override
            (lambda (spec)
              (member (format "%s" (or (font-get spec :family)
                                        (font-get spec :name)))
                      +available-font-families)))
(advice-add 'create-fontset-from-ascii-font :override
            (lambda (_font &optional _resolved name)
              (format "fontset-%s" name)))

(defun +load-setup-fonts ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-ui.el" +repo))
    (re-search-forward "^(defconst \\+default-font ")
    (goto-char (match-beginning 0))
    ;; +default-font, +org-font, the fontset flag, the family helper,
    ;; the Org hook, then +setup-fonts.
    (dotimes (_ 6)
      (eval (read (current-buffer)) t))))

(defun +calls (fn)
  (nreverse (delq nil (mapcar (lambda (call)
                                (and (eq (car call) fn) (cdr call)))
                              +font-calls))))

(defun +font-family (font)
  (cond ((stringp font) font)
        ((fontp font) (format "%s" (font-get font :family)))
        (t nil)))

(+load-setup-fonts)

(+test "tty setup does not touch fonts"
  (let ((+graphic nil)
        (+font-calls nil))
    (+setup-fonts)
    (unless (null +font-calls)
      (error "expected no font calls, got %S" +font-calls))))

(defun +face-fonts ()
  (mapcar (lambda (args)
            (list (car args)
                  (plist-get (cddr args) :font)
                  (plist-get (cddr args) :weight)))
          (+calls 'set-face-attribute)))

(+test "only default locks PragmataPro 14 and weight"
  (require 'cl-lib)
  (let ((+graphic t)
        (+font-calls nil)
        (+default-fontset-configured-p nil))
    (cl-letf (((symbol-function 'face-attribute)
               (lambda (face attr &rest _)
                 (if (and (eq face 'default) (eq attr :family))
                     "PragmataPro"
                   'unspecified))))
      (+setup-fonts))
    (unless (equal (+calls 'set-face-attribute)
                   '((default nil :font "PragmataPro 14" :weight normal)
                     (fixed-pitch nil :family "PragmataPro"
                                  :height unspecified :weight unspecified
                                  :slant unspecified)
                     (fixed-pitch-serif nil :family "PragmataPro"
                                        :height unspecified :weight unspecified
                                        :slant unspecified)
                     (variable-pitch nil :family "PragmataPro"
                                     :height unspecified :weight unspecified
                                     :slant unspecified)))
      (error "face fonts %S" (+calls 'set-face-attribute)))))

(+test "cjk charsets use LXGW WenKai"
  (let ((+graphic t)
        (+font-calls nil)
        (+default-fontset-configured-p nil))
    (+setup-fonts)
    (let ((got nil))
      (dolist (args (+calls 'set-fontset-font))
        (when (and (eq (car args) t)
                   (memq (cadr args) '(han kana hangul cjk-misc bopomofo)))
          (push (list (cadr args) (+font-family (nth 2 args))) got)))
      (setq got (sort got (lambda (a b) (string< (symbol-name (car a))
                                                 (symbol-name (car b))))))
      (unless (equal got '((bopomofo "LXGW WenKai")
                           (cjk-misc "LXGW WenKai")
                           (han "LXGW WenKai")
                           (hangul "LXGW WenKai")
                           (kana "LXGW WenKai")))
        (error "cjk fontset %S" got)))))

(+test "emoji uses the emoji script without scaling or unicode"
  (let ((+graphic t)
        (+font-calls nil)
        (+default-fontset-configured-p nil)
        (face-font-rescale-alist nil))
    (+setup-fonts)
    (let ((emoji nil))
      (dolist (args (+calls 'set-fontset-font))
        (when (memq (cadr args) '(emoji #x1F441 #x1F5C2 unicode))
          (push (list (cadr args) (+font-family (nth 2 args)) (nth 4 args)) emoji)))
      (setq emoji (nreverse emoji))
      (unless (equal emoji '((emoji "Apple Color Emoji" nil)
                             (#x1F441 "Apple Color Emoji" nil)
                             (#x1F5C2 "Apple Color Emoji" nil)))
        (error "emoji fontset %S" emoji)))
    (unless (null face-font-rescale-alist)
      (error "rescale %S" face-font-rescale-alist))
    (unless (null use-default-font-for-symbols)
      (error "use-default-font-for-symbols %S" use-default-font-for-symbols))))

(+test "symbol script prefers PragmataPro then Apple Symbols"
  (let ((+graphic t)
        (+font-calls nil)
        (+default-fontset-configured-p nil))
    (+setup-fonts)
    (let ((symbol (seq-find (lambda (args) (eq (cadr args) 'symbol))
                            (+calls 'set-fontset-font))))
      (unless (and symbol
                   (equal (+font-family (nth 2 symbol)) "PragmataPro")
                   (eq (nth 4 symbol) 'prepend))
        (error "symbol fontset %S" symbol))))
  (let ((+graphic t)
        (+font-calls nil)
        (+default-fontset-configured-p nil)
        (+available-font-families '("Apple Symbols" "Apple Color Emoji")))
    (+setup-fonts)
    (let ((symbol (seq-find (lambda (args) (eq (cadr args) 'symbol))
                            (+calls 'set-fontset-font))))
      (unless (and symbol
                   (equal (+font-family (nth 2 symbol)) "Apple Symbols")
                   (eq (nth 4 symbol) 'prepend))
        (error "fallback symbol fontset %S" symbol)))))

(+test "symbol and emoji fontset entries are not stacked"
  (let ((+graphic t)
        (+font-calls nil)
        (+default-fontset-configured-p nil))
    (+setup-fonts)
    (setq +font-calls nil)
    (+setup-fonts)
    (when (seq-find (lambda (args)
                      (memq (cadr args) '(symbol emoji #x1F441 #x1F5C2)))
                    (+calls 'set-fontset-font))
      (error "fontset entries were added again: %S" (+calls 'set-fontset-font)))))

(+test "org buffers use PragmataPro Liga 14"
  (let ((+font-calls nil))
    (+org-set-buffer-font)
    (let ((hit (seq-find (lambda (args) (eq (car args) 'org-mode-font-face))
                         (+calls 'set-face-attribute))))
      (unless (and hit
                   (eq (cadr hit) nil)
                   (equal (plist-get (cddr hit) :font) "PragmataPro Liga 14"))
        (error "org font %S" hit)))
    (unless (eq buffer-face-mode-face 'org-mode-font-face)
      (error "buffer face %S" buffer-face-mode-face))))

(+test "font setup does not touch table faces"
  (let ((+graphic t)
        (+font-calls nil)
        (+defined-faces '(org-table markdown-ts-table)))
    (+setup-fonts)
    (when (seq-find (lambda (args)
                      (memq (car args) '(org-table markdown-ts-table)))
                    (+calls 'set-face-attribute))
      (error "font setup touched a table face: %S"
             (+calls 'set-face-attribute)))))

(+test "font comment no longer claims equal latin and cjk width"
  (let ((source (with-temp-buffer
                  (insert-file-contents (expand-file-name "core/init-ui.el" +repo))
                  (buffer-string))))
    (when (string-match-p "Same width and height for emoji, chinese and english"
                          source)
      (error "stale equal-width comment remains"))
    (unless (string-match-p "Enable MonoLisaCode ligatures" source)
      (error "ligature comment was not updated"))
    (when (string-match-p "Sarasa/Iosevka" source)
      (error "old ligature comment remains"))))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
