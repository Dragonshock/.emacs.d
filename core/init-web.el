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

(defun +elfeed-show-window ()
  "Return a live window already showing an Elfeed entry, or nil."
  (cl-find-if (lambda (window)
                (with-current-buffer (window-buffer window)
                  (derived-mode-p 'elfeed-show-mode)))
              (window-list nil 'no-minibuf)))

(defun +elfeed-display-entry (buffer)
  "Show BUFFER to the right of the search list.

Reuse an existing entry window so `n' and `SPC' replace the article
instead of deleting that window and splitting again. Point stays in
the entry window."
  (let* ((search (get-buffer-window (elfeed-search-buffer)))
         (existing (+elfeed-show-window))
         (window (if (window-live-p existing)
                     (progn
                       (set-window-buffer existing buffer)
                       existing)
                   (display-buffer-in-direction
                    buffer
                    `((direction . right)
                      (window . ,(or search (selected-window))))))))
    (when (window-live-p window)
      (select-window window))
    window))

(defvar +elfeed-hn-llm nil
  "Force-enable HN Magpie summarization when non-nil even on background updates.

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
  ;; Interactive update always enables HN; background never calls Magpie unattended.
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
  ;; Skips HN Magpie summarization — remote/file feeds + optional Reddit only.
  (run-at-time "1 min" (* 60 60 2) #'elfeed-update-background)
  :bind (:map elfeed-search-mode-map
              ;; Elfeed 3.4 and 4.2: g redraws, G fetches.
              ;; `elfeed-search-update--force' is an obsolete alias of
              ;; `revert-buffer' since 4.0.0.  `elfeed-search-fetch'
              ;; calls `elfeed-update', so the local-feed advice still runs.
              ("g" . revert-buffer)
              ("G" . elfeed-search-fetch)
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
        ;; Right-hand entry window stays up. `n' / `SPC' replace its buffer
        ;; and keep point there. Deleting the window makes the next article
        ;; split again, and the direction then follows `split-window-sensibly'.
        elfeed-show-entry-switch #'+elfeed-display-entry
        elfeed-show-entry-delete #'ignore
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
;; -*- lexical-binding: t; -*-
(use-package telega
  :straight (:host github :repo "zevlg/telega.el"
                   :files (:defaults "contrib/*.el" "etc"))
  :require-incrementally
  (password-cache cl-lib find-func emacsbug
                  telega-customize telega-server telega-root telega-ins
                  telega-match telega-filter telega-chat telega-folders
                  telega-user telega-info telega-media telega-sticker
                  telega-util telega-vvnote telega-webpage telega-notifications
                  telega-modes telega-i18n telega-story telega-completions
                  telega-tdlib telega-tdlib-events t)
  :preface
  (defun +telega-install-tdlib ()
    "Fetch and install telega's expected TDLib commit under ~/.local."
    (interactive)
    (unless (eq system-type 'darwin)
      (user-error "+telega-install-tdlib currently only supports macOS"))
    (require 'telega)
    (require 'compile)
    (let ((script (expand-file-name "scripts/install-telega-tdlib" user-emacs-directory))
          (version (telega-dockrefile-tdlib-version))
          (prefix (expand-file-name "~/.local")))
      (unless (file-executable-p script)
        (user-error "TDLib install script is not executable: %s" script))
      (compilation-start
       (mapconcat #'shell-quote-argument (list script version prefix) " ")
       'compilation-mode
       (lambda (_) "*telega-install-tdlib*"))))

  (defun +telega-toggle-archive ()
    "Toggle telega root buffer between the main and archive filters."
    (interactive)
    (let* ((archive-p (equal (telega-filter-active) '(archive)))
           (filter (if archive-p (list telega-filter-default) '(archive))))
      (telega-filters-push filter)
      (message "telega filter: %s" (if archive-p telega-filter-default 'archive))))

  (defun +telega-reaction-emoji (emoji)
    "Return EMOJI, using the emoji presentation for a plain heart."
    (if (equal emoji "❤") "❤️" emoji))

  (defun +telega-reaction-title (title)
    "Use the emoji presentation when TITLE starts with a plain heart."
    (if (and (stringp title) (string-prefix-p "❤" title))
        (concat "❤️" (substring title 1))
      title))

  (defun +telega-alert--strip-text-properties (args)
    "Strip text properties from the notification spec in ARGS.
`alert' embeds the title and body in a notifier string, where Emacs
text properties are invalid."
    (let ((notify-spec (copy-sequence (car args))))
      (dolist (key '(:title :body))
        (let ((text (plist-get notify-spec key)))
          (when (stringp text)
            (setq notify-spec
                  (plist-put notify-spec key
                             (substring-no-properties text))))))
      (list notify-spec)))

  (defun +telega-save-file-to-clipboard (msg)
    "Save the file attached to MSG onto the system clipboard."
    (interactive (list (telega-msg-for-interactive)))
    (let ((file (telega-msg--content-file msg)))
      (unless file
        (user-error "No file associated with message"))
      (telega-file--download file
        :priority 32
        :update-callback
        (lambda (dfile)
          (telega-msg-redisplay msg)
          (when (telega-file--downloaded-p dfile)
            (let* ((fpath (telega-file--path dfile))
                   (command
                    (if (eq system-type 'darwin)
                        (list "osascript" "-e"
                              (format "set the clipboard to POSIX file %S" fpath))
                      (list "sh" "-c" (format "wl-copy < %s" (shell-quote-argument fpath))))))
              (make-process
               :name "telega-clipboard"
               :buffer nil
               :command command)))))))

  (defun +telega-msg-save-to-cloud-copyleft (msg)
    "Send the file attached to MSG to Saved Messages."
    (interactive (list (telega-msg-for-interactive)))
    (let ((file (telega-msg--content-file msg)))
      (unless file
        (user-error "No file associated with message"))
      (telega-file--download file
        :priority 32
        :update-callback
        (lambda (dfile)
          (telega-msg-redisplay msg)
          (when (telega-file--downloaded-p dfile)
            (let* ((fpath (telega-file--path dfile))
                   (ifile (telega-chatbuf--gen-input-file fpath 'Document)))
              (telega--sendMessage
               (telega-chat-me t)
               (list :@type "inputMessageDocument"
                     :document (list :@type "inputDocument"
                                     :document ifile)
                     :caption (telega-fmt-text "#copyleft")))
              (message "Saved to cloud: %s" (file-name-nondirectory fpath))))))))

  (defun +telega-redraw-for-theme (&rest _)
    "Redraw telega buffers so palette colors follow the enabled theme."
    (when (and (boundp 'telega-root-buffer-name)
               (get-buffer telega-root-buffer-name))
      (telega-root-view--redisplay)
      (dolist (chatbuf (telega-chat-buffers))
        (with-current-buffer chatbuf
          (when telega-chatbuf--ewoc
            (with-telega-buffer-modify
             (telega-save-cursor
               (telega-chatbuf--footer-update)
               (ewoc-refresh telega-chatbuf--ewoc))))))))

  :init
  ;; Read while the other image options take their defaults.
  (setq telega-use-images nil)
  :custom-face
  (telega-msg-heading ((t (:inherit hl-line :background unspecified))))
  (telega-msg-inline-reply ((t (:inherit (hl-line font-lock-function-name-face)))))
  (telega-msg-inline-forward ((t (:inherit (hl-line font-lock-type-face)))))
  (telega-msg-self-title ((t (:bold t :italic t))))
  :bind (:map telega-chat-button-map
              ("h" . nil)
              :map telega-root-mode-map
              ("A" . +telega-toggle-archive)
              :map telega-prefix-map
              ("p" . telega-chatbuf-filter-search)
              ("d" . telega-chat-remove-member)
              ("m" . telega-describe-chat-members)
              :map telega-msg-button-map
              ("C" . +telega-save-file-to-clipboard)
              ("s" . +telega-msg-save-to-cloud-copyleft))
  :hook ((telega-chat-mode . corfu-mode)
         (telega-chat-mode . +telega-completions-setup-capf))
  :config
  (setq telega-root-fill-column 70
        telega-chat-fill-column 90)

  (add-hook! telega-chat-mode-hook
    (defun +telega-disable-visual-fill-column-h ()
      "Disable visual fill column in Telega chat buffers."
      (visual-fill-column-mode -1)))

  (telega-root-auto-fill-mode -1)
  (remove-hook 'telega-chat-mode-hook #'telega-chat-auto-fill-mode)

  (setq telega-chat-show-avatars nil
        telega-user-show-avatars nil
        telega-root-show-avatars nil
        telega-completions-username-show-avatars nil
        telega-active-locations-show-avatars nil
        telega-avatar-text-function (lambda (&rest _) "")

        telega-translate-to-language-by-default "zh"
        telega-chat-input-markups '("markdown2" "org")
        telega-server-libs-prefix (expand-file-name "~/.local")

        ;; root page
        telega-chat-button-width '(0.2 10 25)
        telega-brackets '(((chat (return t)) "" "")
                          ((user (return t)) "" ""))
        telega-chat-button-format-plist (list :with-title 'full-name
                                              :with-username-p nil
                                              :with-title-faces-p nil
                                              :with-unread-trail-p t
                                              :with-members-trail-p nil
                                              :with-bot-verification-p nil
                                              :with-status-icons-trail-p t)

        ;; emoji
        telega-symbol-pin "%"
        telega-symbol-folder ""
        telega-symbol-photo ""
        ;; Avoid Telega's explicit `compose-chars' strings.
        telega-topic-brackets '("⟦" "⟧")
        telega-symbol-forward "→"
        telega-symbol-story-reply "↩"

        ;; filters
        telega-filters-custom nil
        telega-filter-custom-show-folders nil

        ;; images.  `telega-use-images' is set in :init, before these
        ;; options take their defaults.
        telega-emoji-use-images nil
        telega-symbols-emojify
        (cl-reduce (lambda (emojify key)
                     (assq-delete-all key emojify))
                   '(checkmark heavy-checkmark button-close)
                   :initial-value (copy-sequence
                                   (default-value 'telega-symbols-emojify)))

        telega-date-format-alist '((today . "%H:%M") (this-week . "%m/%d") (old . "%m/%d") (date . "%y/%m/%d")
                                   (time . "%H:%M") (date-time . "%y/%m/%d. %H:%M") (date-long . "%y/%m/%d")
                                   (date-break-bar . "%m/%d"))
        telega-chat-group-messages-timespan 600
        telega-completions-capf-functions '(telega-capf-username
                                            telega-capf-hashtag
                                            telega-capf-markdown-precode
                                            telega-capf-botcmd))

  (defun +telega-capf-in-input (capf)
    "Call CAPF only while point is in Telega's writable input area."
    (when (and (markerp telega-chatbuf--input-marker)
               (>= (point) telega-chatbuf--input-marker)
               (not (get-text-property (point) 'read-only)))
      (funcall capf)))

  (defun +telega-completions-setup-capf ()
    "Set up Telega CAPFs without completing read-only message text."
    (telega-completions-setup-capf)
    (setq-local completion-at-point-functions
                (mapcar (lambda (capf)
                          (apply-partially #'+telega-capf-in-input capf))
                        telega-completions-capf-functions)))

  (when (eq system-type 'gnu/linux)
    (add-hook! telega-before-auth-hook
      (defun +telega-enable-linux-proxy-h ()
        "Add and enable the local SOCKS5 proxy before Telega authorizes."
        (telega--addProxy '(:server "127.0.0.1" :port 7891 :type (:@type "proxyTypeSocks5"))
          :enable-p t
          :comment "Local SOCKS5 proxy"))))

  ;; HACK: Work around upstream bot command completion returning nested lists.
  ;; Each mapped candidate list is freshly allocated, so `mapcan' is safe here.
  (defun telega-completions--bot-commands (chat)
    "Return bot command completion candidates for CHAT."
    (let* ((info (telega-chat--info chat))
           (telega-full-info-offline-p nil)
           (full-info (telega--full-info info)))
      (if (telega-chatbuf-match-p '(type bot))
          (telega-completions--bot-commands-list
           (telega--tl-get full-info :bot_info :commands))
        (mapcan (lambda (bot-commands)
                  (telega-completions--bot-commands-list
                   (plist-get bot-commands :commands)
                   (telega-msg-sender-username
                    (telega-user-get
                     (plist-get bot-commands :bot_user_id))
                    'with-@)))
                (plist-get full-info :bot_commands)))))

  ;; HACK: Show full name only in chatbuf
  (defadvice! +telega-message-header-username-only-a
    (orig msg &optional msg-chat msg-sender addon-inserter)
    :around #'telega-ins--message-header
    (let* ((msg (copy-sequence msg))
           (orig-ins (symbol-function 'telega-ins--msg-sender)))
      (setq msg (plist-put msg :author_signature nil))
      (setq msg (plist-put msg :sender_tag nil))
      (setq msg (plist-put msg :sender_boost_count 0))
      (cl-letf (((symbol-function 'telega-ins--msg-sender)
                 (lambda (sender &rest _args)
                   (funcall orig-ins sender
                            :with-title 'full-name
                            :with-username-p nil
                            :with-badges-p nil)))
                ((symbol-function 'telega-chat-admin-get)
                 (lambda (&rest _) nil)))
        (funcall orig msg msg-chat msg-sender addon-inserter))))

  ;; HACK: show stickers
  (defadvice! +telega-enable-image-for-stickers (orig-fn &rest args)
    :around '(telega-sticker--create-image
              telega-describe-stickerset
              telega-ins--sticker-list
              telega-ins--sticker-image
              telega-ins--inline-sticker
              telega-chatbuf-sticker-insert)
    (let ((telega-use-images t))
      (apply orig-fn args)))

  ;; HACK: disable sponsored msg
  (defadvice! +telega-hide-sponsored-messages-a (&rest _)
    :override #'telega-chatbuf-footer-ins-sponsored-messages
    nil)

  (add-hook! telega-ready-hook
    (defun +telega-disable-sponsored-messages-h ()
      (telega--toggleHasSponsoredMessagesEnabled nil)))

  ;; HACK: remove filter line in main filter
  (defadvice! +telega-hide-default-filter-footer-a (orig-fn &rest args)
    :around #'telega-filters--footer
    (if (and (telega-filter-default-p)
             (not telega--sort-criteria)
             (not telega--sort-inverted))
        ""
      (apply orig-fn args)))

  ;; HACK: preview stickers with vertico
  (defadvice! +telega-stickerset-preview-with-vertico-a (fn &rest args)
    :around #'telega-stickerset--minibuf-post-command
    (cl-letf (((symbol-function #'completion-all-sorted-completions)
               (lambda (&rest _)
                 (list (vertico--candidate)))))
      (apply fn args)))

  ;; Lucius-style chat chrome.  His Matrix bridge, notification keyword
  ;; filter, and nerd-icons symbols are not copied: the bridge data is
  ;; personal, and nerd-icons is not part of this telega install.
  (keymap-global-set "C-c t" telega-prefix-map)
  (setq telega-autoplay-mode t
        telega-notifications-mode t
        telega-open-file-function #'org-open-file
        telega-sticker-size '(6 . 24)
        telega-symbol-mark (propertize " " 'face 'telega-button-highlight)
        telega-msg-save-dir "~/Downloads"
        telega-root-default-view-function 'telega-view-folders
        telega-chat-folders-insexp (lambda () nil)
        telega-symbol-rich-text-table-border '(?─ ?\s ?\s)
        telega-builtin-palettes-alist
        '((light
           ((:outline "#b4637a") (:foreground "#b4637a") (:background "#d1c7c7"))
           ((:outline "#ea9d34") (:foreground "#ea9d34") (:background "#d1ccc7"))
           ((:outline "#907aa9") (:foreground "#907aa9") (:background "#cdc7d1"))
           ((:outline "#568D68") (:foreground "#568D68") (:background "#c7d1c7"))
           ((:outline "#286983") (:foreground "#286983") (:background "#cacfcf"))
           ((:outline "#56949f") (:foreground "#56949f") (:background "#c6cbd1"))
           ((:outline "#d7827e") (:foreground "#d7827e") (:background "#d1c7cb")))
          (dark
           ((:outline "#eb6f92") (:foreground "#eb6f92") (:background "#3d2828"))
           ((:outline "#f6c177") (:foreground "#f6c177") (:background "#2c2620"))
           ((:outline "#b294bb") (:foreground "#b294bb") (:background "#2e1e2e"))
           ((:outline "#95b1ac") (:foreground "#95b1ac") (:background "#1e2e1e"))
           ((:outline "#81a2be") (:foreground "#81a2be") (:background "#234242"))
           ((:outline "#9ccfd8") (:foreground "#9ccfd8") (:background "#1e262e"))
           ((:outline "#ebbcba") (:foreground "#ebbcba") (:background "#470528"))))
        telega-box-button-styles
        (let ((styles (copy-tree telega-box-button-styles)))
          (dolist (tag '(owner-sender-tag admin-sender-tag))
            (plist-put (alist-get tag styles) :passive-face 'telega-shadow))
          styles))
  (add-hook 'enable-theme-functions #'+telega-redraw-for-theme)
  (add-hook 'telega-msg-ignore-predicates
            (telega-match-gen-predicate 'msg '(sender is-blocked)))
  (advice-add 'telega-ins--msg-reaction-type :around
              (lambda (fn rt)
                (if (eq (intern (plist-get rt :@type)) 'reactionTypeEmoji)
                    (telega-ins (+telega-reaction-emoji (plist-get rt :emoji)))
                  (funcall fn rt))))
  (advice-add 'telega-msg-reaction-title-for-completion :filter-return
              #'+telega-reaction-title)
  (require 'telega-mnz)
  (global-telega-mnz-mode 1)
  (when (eq system-type 'darwin)
    (require 'telega-alert)
    (advice-add 'telega-alert--notify :filter-args
                #'+telega-alert--strip-text-properties)
    (telega-alert-mode 1))
  )


(use-package telega-dired-dwim
  :after telega
  :demand t)

;; [chirp] twitter client
(use-package chirp
  :straight (:host github :repo "LuciusChen/chirp")
  :commands (chirp-home
             chirp-following
             chirp-bookmarks
             chirp-likes
             chirp-me
             chirp-list
             chirp-search
             chirp-thread
             chirp-profile
             chirp-profile-followers
             chirp-profile-following-users)
  :init
  (setq chirp-cache-directory (no-littering-expand-var-file-name "chirp/")
        chirp-compose-temporary-directory
        (no-littering-expand-var-file-name "chirp/compose/"))
  (make-directory chirp-cache-directory t)
  (make-directory chirp-compose-temporary-directory t)
  :config
  (setq chirp-show-avatars nil
        chirp-show-tweet-media nil
        chirp-tweet-separator ""
        chirp-tweet-separator-indent 0))
;; [browse-url] Pass a URL to browser
(use-package browse-url
  :bind (("C-, o" . browse-url-at-point)
         ("C-, e" . browse-url-emacs)))

;; [eww] Builtin browser
(use-package eww
  :config
  (setq shr-max-image-proportion 0.5))

(use-package xwidget
  :config
  (setq xwidget-webkit-buffer-name-format "*XWidget: %T*"))

(provide 'init-web)
