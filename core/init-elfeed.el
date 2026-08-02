;;; -*- lexical-binding: t -*-

(defvar +elfeed-local-dir (expand-file-name "rss/" user-emacs-directory)
  "Directory for generated local Atom feeds (HN, Reddit, …).")

(defvar +elfeed-reddit-atom
  (expand-file-name "reddit-emacs.atom" +elfeed-local-dir)
  "Path of the private r/emacs Atom file produced by scripts/reddit-elfeed.py.")

(defun +elfeed-file-feed (filename &rest tags)
  "Build an Elfeed feed entry for local FILENAME under `+elfeed-local-dir' with TAGS."
  (cons (concat "file://" (expand-file-name filename +elfeed-local-dir)) tags))

(defun +elfeed-feed-url (feed)
  "Return the URL string of FEED (string or (url . tags) entry)."
  (if (stringp feed) feed (car feed)))

(defun +elfeed-ensure-reddit-feed ()
  "Register the Reddit local feed when its atom file is readable.
Safe to call repeatedly; does not duplicate entries."
  (when (file-readable-p +elfeed-reddit-atom)
    (let* ((entry (+elfeed-file-feed "reddit-emacs.atom" 'r/emacs))
           (url (car entry))
           (known (seq-some (lambda (feed)
                              (equal url (+elfeed-feed-url feed)))
                            elfeed-feeds)))
      (unless known
        (setq elfeed-feeds (append elfeed-feeds (list entry)))))))

(defvar +elfeed-hn-llm nil
  "When non-nil, `scripts/update-elfeed-feeds' runs DeepSeek HN summarization.

Background `elfeed-update-background' never enables this.  Use
`+elfeed-update-with-hn-llm' or set this to t before interactive `g'.")

;; [elfeed] Read rss within Emacs
(use-package elfeed
  :straight t
  :init
  (require 'auth-source)

  ;; Local generators (scripts/update-elfeed-feeds) rewrite rss/*.atom, then
  ;; the original update fetches file:// and remote feeds.
  ;; HN DeepSeek is gated by env ELFEED_HN_LLM (see +elfeed-hn-llm).
  (defadvice! +elfeed-update-after-local-feeds-a (fn &rest args)
    :around '(elfeed-update elfeed-update-background)
    "Refresh local feeds asynchronously, then call FN with ARGS.

If a local-feed process is already running, still invoke FN so remote
feeds keep updating.  Auth-source / GPG failures for the Reddit token
are ignored so a cancelled pinentry cannot abort the whole update.
Missing Reddit token is a soft-skip in the Python script (exit 0).
DeepSeek HN runs only when `+elfeed-hn-llm' is non-nil or ELFEED_HN_LLM
is already set in the environment."
    (if (process-live-p (get-process "elfeed-local-feeds"))
        (progn
          (message "Local feed update is already running; updating remote feeds only")
          (apply fn args))
      (let ((process-environment (copy-sequence process-environment))
            (command (expand-file-name "scripts/update-elfeed-feeds" user-emacs-directory))
            (token (condition-case err
                       (auth-source-pick-first-password :host "reddit-private-rss"
                                                        :port "rss")
                     (error
                      (message "Elfeed: cannot read Reddit RSS token (%s); skipping private feed"
                               (error-message-string err))
                      nil))))
        (when token
          (setenv "REDDIT_PRIVATE_RSS_TOKEN" token))
        (when +elfeed-hn-llm
          (setenv "ELFEED_HN_LLM" "1"))
        (make-process :name "elfeed-local-feeds"
                      :buffer (get-buffer-create "*elfeed-local-feeds*")
                      :command (list command)
                      :noquery t
                      :sentinel
                      (lambda (process _event)
                        (unless (process-live-p process)
                          (unless (zerop (process-exit-status process))
                            (message "Local feed update failed; see *elfeed-local-feeds*"))
                          ;; Atom may have appeared after a successful Reddit fetch.
                          (+elfeed-ensure-reddit-feed)
                          (apply fn args)))))))

  (defun +elfeed-update-with-hn-llm ()
    "Like `elfeed-update', but allow DeepSeek HN summarization once."
    (interactive)
    (let ((+elfeed-hn-llm t))
      (elfeed-update)))

  ;; Background refresh: first run ~1 min after init, then every 2 hours.
  ;; Never sets +elfeed-hn-llm — remote/file feeds only + optional Reddit.
  (run-at-time "1 min" (* 60 60 2) #'elfeed-update-background)
  :bind (:map elfeed-search-mode-map
              ("g" . elfeed-update)
              ("G" . revert-buffer)  ; elfeed-search-update--force obsolete since 4.0.0
              :map elfeed-show-mode-map
              ("M-v" . scroll-down-command)
              ("j" . scroll-up-line)
              ("k" . scroll-down-line))
  :config
  (setq elfeed-db-directory (expand-file-name "elfeed" user-emacs-directory)
        ;; Keep enclosures out of the db tree (data/ + index).
        elfeed-enclosure-default-dir (expand-file-name "elfeed/enclosures" user-emacs-directory)
        elfeed-feeds (list
                      (+elfeed-file-feed "hackernews.atom" 'hackernews)
                      ;; emacs
                      '("https://karthinks.com/index.xml" karthinks)
                      '("https://emacsredux.com/atom.xml" redux)
                      '("https://egh0bww1.com/rss.xml" includeyy)
                      '("https://www.rahuljuliato.com/rss.xml" rahul)
                      ;; r/emacs file feed only if atom exists (see +elfeed-ensure-reddit-feed)
                      ;; programming
                      '("https://matklad.github.io/feed.xml" matklad)
                      '("https://rust-analyzer.github.io/feed.xml" rust-analyzer)
                      '("https://blog.rust-lang.org/feed.xml" rust)
                      ;; news
                      '("https://sspai.com/feed" sspai)
                      '("https://nikonrumors.com/feed/" nikon-rumors)
                      '("https://rss.utgd.net/feed" untaged)
                      ;; tech
                      '("https://www.ithome.com/rss/" ithome)
                      '("https://feeds.feedburner.com/ruanyifeng" RYF)
                      ;; 知乎日报（RSSHub，知乎官方 rss 已挂）
                      '("https://rsshub.rssforever.com/zhihu/daily" zhihu daily)
                      ;; v2ex
                      '("https://www.v2ex.com/feed/tab/all.xml" v2ex)
                      '("https://www.v2ex.com/feed/tab/tech.xml" v2ex tech)
                      ;; youtube
                      '("https://www.youtube.com/feeds/videos.xml?channel_id=UCz0ONCn6eRcDJGsUzupc3TA" ytb-links)
                      '("https://www.youtube.com/feeds/videos.xml?channel_id=UCVTifvD7WFz1Z-AnEzUoUUA" ytb-fansuki)
                      '("https://www.youtube.com/feeds/videos.xml?channel_id=UCiQo406SKypmtAQXIHdZ6mA" ytb-birchpunk)
                      '("https://www.youtube.com/feeds/videos.xml?channel_id=UCue63vweCtx5j6jylVZsd7w" ytb-hummingbird)
                      '("https://www.youtube.com/feeds/videos.xml?channel_id=UCRewJ9oGONpRm_kaYU6UPGQ" ytb-kolar)
                      '("https://www.youtube.com/feeds/videos.xml?channel_id=UCMZZNUTkXjuWlYyB_RwxNKA" ytb-wsf-xmm))
        ;; pop-to-buffer + delete-window: side-by-side search|entry; n/p reuse layout.
        ;; switch-to-buffer + delete-window breaks n/p with sole-window errors.
        elfeed-show-entry-switch #'pop-to-buffer
        elfeed-show-entry-delete #'delete-window
        elfeed-search-clipboard-type 'CLIPBOARD
        elfeed-search-title-max-width 100
        elfeed-search-title-min-width 30
        elfeed-search-trailing-width 25
        elfeed-show-truncate-long-urls t
        elfeed-show-unique-buffers t)

  (+elfeed-ensure-reddit-feed)
  (make-directory elfeed-enclosure-default-dir t)

  ;; Exclude db + enclosure trees from recentf (predicate: path-safe).
  (add-to-list 'recentf-exclude
               (lambda (file)
                 (or (file-in-directory-p file elfeed-db-directory)
                     (file-in-directory-p file elfeed-enclosure-default-dir))))
  )
