;;; -*- lexical-binding: t -*-

;; Gnus is the *mail* client here.  News / blogs / HN live in Elfeed
;; (`init-elfeed.el` + `scripts/update-elfeed-feeds`).  Do not re-add
;; nnnrss/nnatom secondary methods when syncing roife/.emacs.d.

;; [gnus] mail reader (nnmaildir) + composer (message/smtpmail)
(use-package gnus
  :commands gnus
  :config
  (setq
   gnus-use-cache t
   gnus-use-header-prefetch t
   gnus-asynchronous t

   ;; mark duplicate copies
   gnus-suppress-duplicates t
   ;; be quiet
   gnus-interactive-exit 'quiet
   gnus-inhibit-startup-message t
   ;; Close network connections before macOS goes to sleep.
   gnus-close-on-sleep t
   ;; Do not persist killed groups or use the legacy .newsrc file.
   gnus-save-killed-list nil
   gnus-save-newsrc-file nil
   gnus-read-newsrc-file nil
   ;; Automatically restore the local Gnus state journal after an unclean
   ;; exit instead of prompting about .newsrc-dribble.
   gnus-always-read-dribble-file t
   ;; Discover local Maildir folders at startup and subscribe alphabetically.
   gnus-check-new-newsgroups 'ask-server
   gnus-subscribe-newsgroup-method 'gnus-subscribe-alphabetically
   ;; A unified query lang (usable once a search engine is wired).
   gnus-search-use-parsed-queries t

   ;; article mode
   gnus-article-sort-functions '((not gnus-article-sort-by-number)
                                 (not gnus-article-sort-by-date))
   gnus-article-browse-delete-temp t

   ;; Display more MIME stuff
   gnus-mime-display-multipart-related-as-mixed t

   ;; Experienced-user UI; sending still asks via `message-confirm-send'.
   gnus-novice-user nil
   gnus-expert-user t)

  ;; NEWS 31: gnus-close-on-sleep hooks system-sleep-event-functions, but
  ;; stock does not (require 'system-sleep).  loaddefs pre-defvars the hook
  ;; with NOSET autoload, so add-hook alone never loads the library and
  ;; system-sleep-enable (special-event-map) never runs — silent no-op on
  ;; macOS sleep.  Both local and roife only set the flag.  Force load here.
  (when gnus-close-on-sleep
    (require 'system-sleep))

  ;; Primary: nothing.  Secondary: local Gmail Maildir (isync Verbatim).
  ;;
  ;; isync layout is hierarchical, not flat:
  ;;   ~/.local/share/mail/gmail/Inbox
  ;;   ~/.local/share/mail/gmail/[Gmail]/{Sent Mail,All Mail,...}
  ;; nnmaildir only lists *immediate* child maildirs of `directory', so
  ;; Inbox and Gmail labels need two server roots (not "[Gmail].Sent Mail").
  ;; RSS/Atom → Elfeed.  Do not re-add nnnrss/nnatom from roife.
  (setq gnus-select-method '(nnnil "")
        gnus-secondary-select-methods
        '((nnmaildir "GMail"
                     (directory "~/.local/share/mail/gmail/"))
          (nnmaildir "GMailLabels"
                     (directory "~/.local/share/mail/gmail/[Gmail]/")))
        ;; Gmail already keeps server-side Sent; no local monthly archive.
        gnus-message-archive-group nil)

  (defun +gnus-ensure-gmail-folders ()
    "Subscribe all isync Gmail folders; drop feed + wrong-name groups.

isync Patterns (Verbatim) map to:
  nnmaildir+GMail:Inbox
  nnmaildir+GMailLabels:{All Mail,Sent Mail,Drafts,Trash,Spam}
Topics (seeded in etc/gnus/newsrc.eld): mail / system / misc.
Safe on every `gnus-started-hook'."
    (dolist (spec '(("nnmaildir+GMail:Inbox" 3)
                    ("nnmaildir+GMailLabels:All Mail" 4)
                    ("nnmaildir+GMailLabels:Sent Mail" 4)
                    ("nnmaildir+GMailLabels:Drafts" 5)
                    ("nnmaildir+GMailLabels:Trash" 6)
                    ("nnmaildir+GMailLabels:Spam" 6)))
      (let ((group (car spec))
            (level (cadr spec)))
        (unless (gnus-group-entry group)
          (ignore-errors (gnus-subscribe-newsgroup group)))
        (when (gnus-group-entry group)
          (gnus-group-change-level group level))))
    ;; Drop legacy feed backends and the mistaken flat Gmail names.
    (dolist (entry (copy-sequence gnus-newsrc-alist))
      (let ((group (car entry)))
        (when (and (stringp group)
                   (or (string-match-p "\\`nn\\(atom\\|nrss\\|rss\\)" group)
                       (string-match-p "\\`nnmaildir\\+GMail:\\[Gmail\\]" group)
                       ;; Parent dir is not a maildir; ignore if ever subscribed.
                       (string-equal group "nnmaildir+GMail:[Gmail]")))
          (ignore-errors
            (gnus-group-unsubscribe-group group nil t))))))

  (add-hook 'gnus-started-hook #'+gnus-ensure-gmail-folders))


;; [gnus-group] group mode
(use-package gnus-group
  :config
  ;;               indentation ------------.
  ;;       #      process mark ----------. |
  ;;                     level --------. | |
  ;;                subscribed ------. | | |
  ;;       %          new mail ----. | | | |
  ;;       *   marked articles --. | | | | |
  ;;                             | | | | | |  Ticked    New     Unread  open-status Group
  (setq gnus-group-line-format "%M%m%S%L%p%P %1(%7i%) %3(%7U%) %3(%7y%) %4(%B%-45G%)\n"
        gnus-group-sort-function
        '(gnus-group-sort-by-level gnus-group-sort-by-alphabet))

  (defvar +gnus--refresh-process nil
    "The process updating external sources before a Gnus refresh.")

  (defadvice! +gnus--sync-before-refresh (refresh &rest args)
    :around #'gnus-group-get-new-news
    "Run isync (mbsync) before REFRESH with ARGS.

Mail only: Hacker News and other feeds are updated by Elfeed
(`scripts/update-elfeed-feeds`), not by this path."
    (if (and +gnus--refresh-process
             (process-live-p +gnus--refresh-process))
        (message "Mail synchronization is already running")
      (let ((group-buffer (current-buffer))
            (output-buffer (get-buffer-create "*gnus-source-update*"))
            (command
             (list
              (expand-file-name "scripts/update-gnus-sources"
                                user-emacs-directory))))
        (with-current-buffer output-buffer
          (erase-buffer))
        (setq +gnus--refresh-process
              (make-process
               :name "gnus-mbsync"
               :buffer output-buffer
               :command '("mbsync" "--all")
               :noquery t
               :sentinel
               (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (setq +gnus--refresh-process nil)
                   (if (zerop (process-exit-status process))
                       (message "Mail synchronized")
                     (message
                      "Mail sync failed; see %s"
                      (buffer-name (process-buffer process))))
                   ;; Refresh even after a partial failure: existing local
                   ;; Maildir remains usable.
                   (when (buffer-live-p group-buffer)
                     (with-current-buffer group-buffer
                       (apply refresh args)))))))
        (message "Synchronizing mail...")))))

(use-package gnus-topic
  :after gnus-group
  :hook (gnus-group-mode . gnus-topic-mode))

(use-package gnus-demon
  :after gnus
  :config
  (gnus-demon-add-handler #'gnus-demon-scan-news 30 nil)
  (add-hook! gnus-started-hook #'gnus-demon-init))


;; [gnus-sum] summary mode
(use-package gnus-sum
  :after gnus
  :config
  (setq
   ;; Pretty marks
   gnus-sum-thread-tree-root            "┌ "
   gnus-sum-thread-tree-false-root      "◌ "
   gnus-sum-thread-tree-single-indent   "◎ "
   gnus-sum-thread-tree-vertical        "│"
   gnus-sum-thread-tree-indent          "  "
   gnus-sum-thread-tree-leaf-with-other "├─►"
   gnus-sum-thread-tree-single-leaf     "╰─►"
   gnus-summary-line-format "%U%R %3d %[%-23,23f%] %B %s\n"
   ;; Loose threads
   gnus-simplify-subject-functions '(gnus-simplify-subject-re gnus-simplify-whitespace)
   gnus-summary-thread-gathering-function 'gnus-gather-threads-by-subject
   ;; Filling in threads
   gnus-fetch-old-headers 2
   gnus-fetch-old-ephemeral-headers 2
   gnus-build-sparse-threads 'some
   gnus-thread-indent-level 2
   gnus-thread-sort-functions 'gnus-thread-sort-by-most-recent-date
   gnus-subthread-sort-functions 'gnus-thread-sort-by-date
   gnus-view-pseudos 'automatic
   gnus-view-pseudo-asynchronously t
   gnus-auto-select-first nil
   gnus-auto-select-next nil
   gnus-paging-select-next nil))


;; Identity / SMTP — independent of Gnus so `compose-mail' / `report-emacs-bug'
;; work before the first `M-x gnus'.  Do not put these under `:after gnus'.
;; Align with ~/.config/isyncrc (User) and authinfo smtp.gmail.com login.
(setq user-full-name "LongZhen"
      user-mail-address "longzhen9490@gmail.com"
      send-mail-function #'smtpmail-send-it
      smtpmail-smtp-server "smtp.gmail.com"
      smtpmail-smtp-user user-mail-address
      smtpmail-smtp-service 465
      smtpmail-stream-type 'ssl
      smtpmail-servers-requiring-authorization "\\`smtp\\.gmail\\.com\\'"
      message-send-mail-function #'message-use-send-mail-function)

;; [message] Composing mail (hooks / message-local options only)
(use-package message
  :defer t
  :hook (message-mode . auto-fill-mode)
  :config
  (setq message-kill-buffer-on-exit t
        message-confirm-send t
        message-signature user-full-name
        message-mail-alias-type 'ecomplete))


;; Attach marked files from Dired with `C-c RET C-a'.
(use-package gnus-dired
  :after dired
  :hook (dired-mode . turn-on-gnus-dired-mode))
