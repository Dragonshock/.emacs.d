;;; -*- lexical-binding: t -*-

(defvar +elfeed-local-dir (no-littering-expand-var-file-name "rss/")
  "Directory for local Atom feeds (HN, Reddit, …) under no-littering `var/rss/'.")

(defvar +elfeed-hn-atom
  (expand-file-name "hackernews.atom" +elfeed-local-dir)
  "Path of the HN Atom file written by scripts/hn-elfeed.py.")

(defvar +elfeed-reddit-atom
  (expand-file-name "reddit-emacs.atom" +elfeed-local-dir)
  "Path of the private r/emacs Atom file produced by scripts/reddit-elfeed.py.")

(defun +elfeed-file-feed (filename &rest tags)
  "Build an Elfeed feed entry for local FILENAME under `+elfeed-local-dir' with TAGS."
  (cons (concat "file://" (expand-file-name filename +elfeed-local-dir)) tags))

(defun +elfeed-hn-feed (&rest tags)
  "Build the Hacker News file:// feed entry with TAGS (default hackernews)."
  (cons (concat "file://" +elfeed-hn-atom) (or tags '(hackernews))))

(defun +elfeed-feed-url (feed)
  "Return the URL string of FEED (string or (url . tags) entry)."
  (if (stringp feed) feed (car feed)))

(defvar +elfeed-ithome-url "https://rsshub.rssforever.com/ithome/it"
  "IT之家「IT 资讯」分类源（RSSHub）。官网总 RSS 混入智车之家通稿。")

;; V2EX hard ads: scoped to v2ex.com in `+elfeed-tag-promo-entry'.
(defvar +elfeed-ad-title-regexp
  (rx (or "中转" "机场" "[招聘]" "[接活]" "[广告]" "免费领"))
  "Title regexp for V2EX-style hard ads.")

;; IT之家 product PR: brand × shelf signal, minus industry-news exclusions.
(defvar +elfeed-pr-brand-regexp
  (rx (or "vivo" "OPPO" "iQOO" "真我" "红米" "REDMI" "小米" "荣耀"
          "华为" "一加" "realme" "魅族" "三星"
          "比亚迪" "长城" "魏牌" "奇瑞" "红旗" "吉利" "长安" "一汽"
          "理想" "问界" "小鹏" "蔚来" "极氪" "阿维塔" "零跑"
          "丰田" "本田" "大众" "奔驰" "宝马" "奥迪" "捷豹" "路虎"
          "启境" "深蓝" "方程豹" "腾势" "智己" "飞凡" "iCAR"))
  "Consumer brands used to detect IT之家 product-PR titles.")

(defvar +elfeed-pr-signal-regexp
  (rx (or "规格曝光" "开启预售" "限时权益价" "到手价" "万元起" "元起"
          "预售价" "首发亮相" "高定车色" "车色" "车展"
          "开售" "预售" "上市"))
  "Shelf/launch phrasing that, with a brand, marks a title as PR.")

(defvar +elfeed-pr-exclude-regexp
  (rx (or "专利" "开源" "罢工" "灰度" "推送" "论文" "研究"))
  "If present, the title is treated as industry news rather than PR.")

(defun +elfeed-ad-title-p (title)
  "Return non-nil if TITLE looks like a V2EX hard ad."
  (and (stringp title)
       (let ((case-fold-search t))
         (string-match-p +elfeed-ad-title-regexp title))))

(defun +elfeed-pr-title-p (title)
  "Return non-nil if TITLE looks like an IT之家 product-PR item."
  (and (stringp title)
       (let ((case-fold-search t))
         (and (string-match-p +elfeed-pr-brand-regexp title)
              (string-match-p +elfeed-pr-signal-regexp title)
              (not (string-match-p +elfeed-pr-exclude-regexp title))))))

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
  "Force-enable HN DeepSeek when non-nil even on background updates.

Interactive `elfeed-update' (search `g') always runs HN generation.
`elfeed-update-background' never does, unless this variable is non-nil.
Shell gate remains ELFEED_HN_LLM (see scripts/update-elfeed-feeds).")

;; [elfeed] Read rss within Emacs
(use-package elfeed
  :straight t
  :init
  (require 'auth-source)

  ;; Local generators rewrite Atom files, then the original update fetches
  ;; file:// + remote feeds.  All local atoms live under var/rss/ (no-littering).
  ;; Interactive update always enables HN; background never pays DeepSeek unattended.
  ;; Two :around hooks (not one shared) so RUN-HN is reliable — nadvice's
  ;; FN argument is a wrapper object, not eq to #'elfeed-update.
  (defun +elfeed--update-after-local-feeds (fn args run-hn)
    "Refresh local feeds asynchronously, then apply FN to ARGS.
When RUN-HN is non-nil (or `+elfeed-hn-llm'), export ELFEED_HN_LLM=1."
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
        (when (or run-hn +elfeed-hn-llm)
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

  (defadvice! +elfeed-update-after-local-feeds-a (fn &rest args)
    :around #'elfeed-update
    "Like `+elfeed--update-after-local-feeds' with HN generation enabled."
    (+elfeed--update-after-local-feeds fn args t))

  (defadvice! +elfeed-update-background-after-local-feeds-a (fn &rest args)
    :around #'elfeed-update-background
    "Like `+elfeed--update-after-local-feeds' without HN (unless forced)."
    (+elfeed--update-after-local-feeds fn args nil))

  (defun +elfeed-update-with-hn-llm ()
    "Alias of `elfeed-update' (interactive path always runs HN generation)."
    (interactive)
    (elfeed-update))

  ;; Background refresh: first run ~1 min after init, then every 2 hours.
  ;; Skips HN DeepSeek — remote/file feeds + optional Reddit only.
  (run-at-time "1 min" (* 60 60 2) #'elfeed-update-background)
  :bind (:map elfeed-search-mode-map
              ("g" . elfeed-update)
              ("G" . revert-buffer)  ; elfeed-search-update--force obsolete since 4.0.0
              :map elfeed-show-mode-map
              ("M-v" . scroll-down-command)
              ("j" . scroll-up-line)
              ("k" . scroll-down-line))
  :config
  ;; elfeed-db-directory / elfeed-enclosure-default-dir: leave to no-littering
  ;; (var/elfeed/db/, var/elfeed/enclosures/).  Do not override to config root.
  (make-directory +elfeed-local-dir t)
  (setq elfeed-feeds (list
                      ;; HN atom: var/rss/hackernews.atom (scripts/hn-elfeed.py)
                      (+elfeed-hn-feed 'hackernews)
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
                      '("https://plink.anyfeeder.com/people-daily" people-daily news)
                      ;; tech (IT之家: RSSHub 分类源，不用官网总 RSS)
                      (list +elfeed-ithome-url 'ithome)
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
        elfeed-show-unique-buffers t
        ;; Hide V2EX hard ads (`ad') and IT之家 product PR (`pr').
        elfeed-search-filter "@6months +unread -ad -pr")
  (setq-default elfeed-search-filter "@6months +unread -ad -pr")

  (defun +elfeed-entry-feed-url (entry)
    "Return the feed URL of ENTRY, or nil."
    (let ((feed (elfeed-entry-feed entry)))
      (and feed (elfeed-feed-url feed))))

  (defun +elfeed-tag-promo-entry (entry)
    "Tag ENTRY as `ad' (V2EX hard ad) or `pr' (IT之家 product PR)."
    (let* ((title (elfeed-entry-title entry))
           (url (or (+elfeed-entry-feed-url entry) "")))
      (cond
       ((and (string-match-p "v2ex\\.com" url)
             (+elfeed-ad-title-p title))
        (elfeed-tag entry 'ad))
       ((and (string-match-p "ithome" url)
             (+elfeed-pr-title-p title))
        (elfeed-tag entry 'pr)))))

  (defun +elfeed-dedup-ithome-entry (entry)
    "Drop `unread' when ENTRY is an RSSHub IT之家 copy of an older link."
    (let ((url (or (+elfeed-entry-feed-url entry) ""))
          (link (elfeed-entry-link entry)))
      (when (and link
                 (hash-table-p elfeed-db-entries)
                 (string-match-p "rsshub\\..*/ithome" url))
        (catch 'found
          (maphash
           (lambda (_id other)
             (when (and (not (eq other entry))
                        (stringp (elfeed-entry-link other))
                        (string= (elfeed-entry-link other) link))
               (elfeed-untag entry 'unread)
               (throw 'found t)))
           elfeed-db-entries)))))

  (defun +elfeed-backfill-promo-tags ()
    "Apply promo tags to every existing entry and save the database."
    (interactive)
    (let ((n-ad 0)
          (n-pr 0))
      (with-elfeed-db-visit (entry _feed)
        (let ((had-ad (elfeed-tagged-p 'ad entry))
              (had-pr (elfeed-tagged-p 'pr entry)))
          (+elfeed-tag-promo-entry entry)
          (unless had-ad
            (when (elfeed-tagged-p 'ad entry)
              (setq n-ad (1+ n-ad))))
          (unless had-pr
            (when (elfeed-tagged-p 'pr entry)
              (setq n-pr (1+ n-pr))))))
      (elfeed-db-save)
      (when (fboundp 'elfeed-search-update)
        (elfeed-search-update :force))
      (message "Elfeed promo backfill: %d ad, %d pr" n-ad n-pr)
      (list :ad n-ad :pr n-pr)))

  (add-hook 'elfeed-new-entry-hook #'+elfeed-tag-promo-entry)
  (add-hook 'elfeed-new-entry-hook #'+elfeed-dedup-ithome-entry)

  (+elfeed-ensure-reddit-feed)
  (make-directory elfeed-enclosure-default-dir t)

  ;; Exclude db + enclosure trees from recentf (predicate: path-safe).
  (add-to-list 'recentf-exclude
               (lambda (file)
                 (or (file-in-directory-p file elfeed-db-directory)
                     (file-in-directory-p file elfeed-enclosure-default-dir))))
  )
