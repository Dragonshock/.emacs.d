;;; -*- lexical-binding: t -*-

;; Batch checks for the Lucius-style telega settings.
;;   emacs -Q --batch -l scripts/test-telega-lucius.el
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

(defun +read (name)
  (with-temp-buffer
    (insert-file-contents (expand-file-name name +repo))
    (buffer-string)))

(defconst +social (+read "core/init-social.el"))

(defun +load-defun (name)
  (with-temp-buffer
    (insert +social)
    (goto-char (point-min))
    (re-search-forward (format "(defun %s " (regexp-quote name)))
    (goto-char (match-beginning 0))
    (eval (read (current-buffer)) t)))

(+load-defun "+telega-reaction-emoji")
(+load-defun "+telega-reaction-title")
(+load-defun "+telega-alert--strip-text-properties")

(defun +has (needle)
  (or (string-match-p (regexp-quote needle) +social)
      (error "missing %s" needle)))

(+test "lucius chrome settings are present"
  (+has "\"C-c t\" telega-prefix-map")
  (+has "telega-chatbuf-filter-search")
  (+has "telega-chat-remove-member")
  (+has "telega-describe-chat-members")
  (+has "+telega-save-file-to-clipboard")
  (+has "+telega-msg-save-to-cloud-copyleft")
  (+has "telega-autoplay-mode t")
  (+has "telega-notifications-mode t")
  (+has "#'org-open-file")
  (+has "telega-chat-fill-column 90")
  (+has "telega-root-fill-column 70")
  (+has "telega-sticker-size '(6 . 24)")
  (+has "telega-root-default-view-function 'telega-view-default")
  (+has "(global-telega-mnz-mode 1)")
  (+has "(sender is-blocked)")
  (+has "\"markdown2\" \"org\"")
  (+has "telega-builtin-palettes-alist")
  (+has "#copyleft")
  (+has "+telega-redraw-for-theme"))

(+test "local guards stay in place"
  (+has ":repo \"zevlg/telega.el\"")
  (+has "telega-use-images nil")
  (+has ":port 7891")
  (+has "+telega-install-tdlib")
  (+has "+telega-capf-in-input")
  (+has ":bot_user_id")
  (+has "telega-chatbuf-footer-ins-sponsored-messages")
  (+has "telega-avatar-text-function"))

(+test "personal lucius data is absent"
  (dolist (needle '("telega-bridge-bot"
                    "telega-notifications-msg-temex"
                    "@Lucius_Chen"
                    "auth-source-pick-first-password"
                    "LuciusChen/telega.el"
                    "nerd-icons-mdicon"))
    (when (string-match-p (regexp-quote needle) +social)
      (error "unexpected %s" needle))))

(+test "plain heart becomes the emoji presentation"
  (unless (equal (+telega-reaction-emoji "❤") "❤️")
    (error "heart %S" (+telega-reaction-emoji "❤")))
  (unless (equal (+telega-reaction-emoji "👍") "👍")
    (error "other %S" (+telega-reaction-emoji "👍")))
  (unless (equal (+telega-reaction-title "❤ red heart") "❤️ red heart")
    (error "title %S" (+telega-reaction-title "❤ red heart")))
  (unless (equal (+telega-reaction-title "👍 thumbs") "👍 thumbs")
    (error "other title %S" (+telega-reaction-title "👍 thumbs"))))

(+test "alert advice strips text properties and keeps one spec"
  (let* ((title (propertize "Hello" 'face 'bold))
         (body (propertize "Body" 'face 'italic))
         (got (+telega-alert--strip-text-properties
               (list (list :title title :body body :other 'kept)))))
    (unless (and (= (length got) 1)
                 (equal (plist-get (car got) :title) "Hello")
                 (null (text-properties-at 0 (plist-get (car got) :title)))
                 (equal (plist-get (car got) :body) "Body")
                 (null (text-properties-at 0 (plist-get (car got) :body))))
      (error "stripped %S" got))))

(if +test-failures
    (kill-emacs 1)
  (kill-emacs 0))
