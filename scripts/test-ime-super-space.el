;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-ime-super-space.el
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

(defconst +mac
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-mac.el" +repo))
    (buffer-string)))

(defun +mac-bind-keys-form ()
  "Return the `bind-keys' form in `core/init-mac.el'."
  (with-temp-buffer
    (insert +mac)
    (goto-char (point-min))
    (re-search-forward "(bind-keys\\_>")
    (goto-char (match-beginning 0))
    (read (current-buffer))))

(+test "s-SPC toggles the input method like C-\\"
  (let* ((form (+mac-bind-keys-form))
         (binding (assoc "s-SPC" (cdr form)))
         (map (make-sparse-keymap)))
    (unless (eq (cdr binding) 'toggle-input-method)
      (error "binding %S" binding))
    (define-key map (kbd "s-SPC") (cdr binding))
    (unless (eq (lookup-key map (kbd "s-SPC")) 'toggle-input-method)
      (error "lookup %S" (lookup-key map (kbd "s-SPC"))))))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
