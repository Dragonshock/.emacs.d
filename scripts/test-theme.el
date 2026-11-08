;;; -*- lexical-binding: t -*-

;;   emacs -Q --batch -l scripts/test-theme.el
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

(defconst +ui
  (with-temp-buffer
    (insert-file-contents (expand-file-name "core/init-ui.el" +repo))
    (buffer-string)))

(+test "graphical themes are ashen day and night"
  (unless (string-match-p "(defvar \\+light-theme 'ashen-day)" +ui)
    (error "light theme is not ashen-day"))
  (unless (string-match-p "(defvar \\+dark-theme 'ashen-night)" +ui)
    (error "dark theme is not ashen-night"))
  (unless (string-match-p ":repo \"LuciusChen/ashen\"" +ui)
    (error "ashen recipe missing"))
  (when (string-match-p "doom-themes" +ui)
    (error "doom-themes is still loaded"))
  (unless (string-match-p "(load-theme theme t)" +ui)
    (error "theme loader was removed")))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
