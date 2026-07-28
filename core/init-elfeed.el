;;; -*- lexical-binding: t -*-

(defvar +elfeed-local-dir (expand-file-name "rss/" user-emacs-directory))

;; [elfeed] Read rss within Emacs
(use-package elfeed
  :straight t
  :init
  (require 'auth-source)

  (defadvice! +elfeed-update-after-local-feeds-a (fn &rest args)
    :around '(elfeed-update elfeed-update-background)
    "Refresh local feeds asynchronously, then call FN with ARGS."
    (if (process-live-p (get-process "elfeed-local-feeds"))
        (message "Local feed update is already running")
      (let ((process-environment (copy-sequence process-environment))
            (command (expand-file-name "scripts/update-elfeed-feeds" user-emacs-directory)))
        (setenv "REDDIT_PRIVATE_RSS_TOKEN"
                (auth-source-pick-first-password :host "reddit-private-rss"
                                                 :port "rss"))
        (make-process :name "elfeed-local-feeds"
                      :buffer (get-buffer-create "*elfeed-local-feeds*")
                      :command (list command)
                      :noquery t
                      :sentinel
                      (lambda (process _event)
                        (unless (process-live-p process)
                          (unless (zerop (process-exit-status process))
                            (message "Local feed update failed; see *elfeed-local-feeds*"))
                          (apply fn args)))))))

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
        elfeed-feeds `((,(concat "file://" (expand-file-name "hackernews.atom" +elfeed-local-dir)) hackernews)
                       ;; emacs
                       ("https://karthinks.com/index.xml" karthinks)
                       ("https://emacsredux.com/atom.xml" redux)
                       ("https://egh0bww1.com/rss.xml" includeyy)
                       ("https://www.rahuljuliato.com/rss.xml" rahul)
                       (,(concat "file://" (expand-file-name "reddit-emacs.atom" +elfeed-local-dir)) r/emacs)
                       ;; programming
                       ("https://matklad.github.io/feed.xml" matklad)
                       ("https://rust-analyzer.github.io/feed.xml" rust-analyzer)
                       ("https://blog.rust-lang.org/feed.xml" rust)
                       ;; news
                       ("https://sspai.com/feed" sspai)
                       ("https://nikonrumors.com/feed/" nikon-rumors)
                       ("https://rss.utgd.net/feed" untaged)
                       ;; tech
                       ("https://www.ithome.com/rss/" ithome)
                       ("http://feeds.feedburner.com/ruanyifeng" RYF)
                       ;; 知乎日报（RSSHub，知乎官方 rss 已挂）
                       ("https://rsshub.rssforever.com/zhihu/daily" zhihu daily)
                       ;; v2ex
                       ("https://www.v2ex.com/feed/tab/all.xml" v2ex)
                       ("https://www.v2ex.com/feed/tab/tech.xml" v2ex tech)
                       ;; youtube
                       ("https://www.youtube.com/feeds/videos.xml?channel_id=UCz0ONCn6eRcDJGsUzupc3TA" ytb-links)
                       ("https://www.youtube.com/feeds/videos.xml?channel_id=UCVTifvD7WFz1Z-AnEzUoUUA" ytb-fansuki)
                       ("https://www.youtube.com/feeds/videos.xml?channel_id=UCiQo406SKypmtAQXIHdZ6mA" ytb-birchpunk)
                       ("https://www.youtube.com/feeds/videos.xml?channel_id=UCue63vweCtx5j6jylVZsd7w" ytb-hummingbird)
                       ("https://www.youtube.com/feeds/videos.xml?channel_id=UCRewJ9oGONpRm_kaYU6UPGQ" ytb-kolar)
                       ("https://www.youtube.com/feeds/videos.xml?channel_id=UCMZZNUTkXjuWlYyB_RwxNKA" ytb-wsf-xmm))
        elfeed-enclosure-default-dir (expand-file-name "elfeed/" user-emacs-directory)
        elfeed-show-entry-switch #'switch-to-buffer
        elfeed-show-entry-delete #'delete-window
        elfeed-search-clipboard-type 'CLIPBOARD
        elfeed-search-title-max-width 100
        elfeed-search-title-min-width 30
        elfeed-search-trailing-width 25
        elfeed-show-truncate-long-urls t
        elfeed-show-unique-buffers t)

  ;; Ignore db directory in recentf
  (push elfeed-db-directory recentf-exclude)
  )
