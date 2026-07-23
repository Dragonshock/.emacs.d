;;; -*- lexical-binding: t -*-

;; [elfeed] Read rss within Emacs
(use-package elfeed
  :straight t
  :bind (:map elfeed-search-mode-map
              ("g" . elfeed-update)
              ("G" . elfeed-search-update--force)
              :map elfeed-show-mode-map
              ("M-v" . scroll-down-command)
              ("j" . scroll-up-line)
              ("k" . scroll-down-line))
  :config
  (setq elfeed-db-directory (expand-file-name "elfeed" user-emacs-directory)
        elfeed-feeds `((,(concat "file://" (expand-file-name "rss/feed.atom"
                                                             user-emacs-directory))
                        hackernews ai zh)
                       ;; emacs
                       ("https://karthinks.com/index.xml" karthinks)
                       ("https://emacsredux.com/atom.xml" redux)
                       ("https://egh0bww1.com/rss.xml" includeyy)
                       ("https://www.rahuljuliato.com/rss.xml" rahul)
                       ("https://emacs-china.org/latest.rss" emacs-china)
                       ;; programming
                       ("https://matklad.github.io/feed.xml" matklad)
                       ("https://rust-analyzer.github.io/feed.xml" rust-analyzer)
                       ("https://blog.rust-lang.org/feed.xml" rust))
        elfeed-enclosure-default-dir (expand-file-name "elfeed/" user-emacs-directory)
        elfeed-show-entry-switch #'pop-to-buffer
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
