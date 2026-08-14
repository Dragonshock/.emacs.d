;;; -*- lexical-binding: t -*-

;; [vc-mode] Version control interface
(use-package vc
  :config
  ;; NOTE: `vc-auto-revert-mode' (new in Emacs 31.1) is a globalized minor
  ;; mode, so `setq'-ing it never enabled anything.  Deliberately left off:
  ;; enabling it would run real `auto-revert-mode' (timer + file notifications)
  ;; in every VC-tracked buffer, which is exactly what `+auto-revert-mode' in
  ;; init-edit.el exists to avoid.
  (setq vc-handled-backends '(Git)
        vc-consult-headers nil
        vc-allow-async-revert t
        ;; Emacs 31: `t' rewrites published history with no prompt — prefer ask.
        vc-allow-rewriting-published-history 'ask
        vc-dir-auto-hide-up-to-date 'revert))


;; [git-link] Get remote repo URL for buffer location
(use-package git-link
  :straight t
  :bind (("C-, g l" . git-link)
         ("C-, g c" . git-link-commit)
         ("C-, g h" . git-link-homepage)))


;; [diff-hl] Highlight uncommitted changes using VC
(use-package diff-hl
  :straight t
  ;; Enable global mode once at startup (not on every find-file — that
  ;; re-runs globalized-mode body and rescans the buffer list each open).
  :hook ((after-init . global-diff-hl-mode)
         (vc-dir-mode  . diff-hl-dir-mode)
         (dired-mode   . diff-hl-dired-mode))
  :bind (:map diff-hl-mode-map
              ("C-c v v" . diff-hl-show-hunk)
              ("C-c v r" . diff-hl-revert-hunk)
              ("C-c v [" . diff-hl-previous-hunk)
              ("C-c v ]" . diff-hl-next-hunk)
              ("C-c v s" . diff-hl-stage-current-hunk)
              ;; `diff-hl-undo-revert-hunk' does not exist; use plain undo after revert.
              ("C-c v u" . undo))
  :config
  (setq
   ;; Reduce load on remote
   diff-hl-disable-on-remote t
   ;; A slightly faster algorithm for diffing
   vc-git-diff-switches '("--histogram"))

  (defun +diff-hl--vc-face (type)
    (pcase type
      ('insert 'diff-refine-added)
      ('delete 'diff-refine-removed)
      ('change 'diff-refine-changed)))

  (setq diff-hl-fringe-face-function #'(lambda (type _pos) (+diff-hl--vc-face type))
        diff-hl-fringe-reference-face-function #'(lambda (type _pos) (+diff-hl--vc-face type)))

  ;; Integration with magit
  (with-eval-after-load 'magit
    (add-hook! magit-post-refresh-hook #'diff-hl-magit-post-refresh))

  ;; WORKAROUND: Integration with ws-butler
  (with-eval-after-load 'ws-butler
    (advice-add #'ws-butler-after-save :after #'diff-hl-update))

  ;; HACK: Update after vc-state refreshed
  (advice-add #'vc-refresh-state :after #'diff-hl-update)

  ;; Update after focus change for different mode.
  (defun +diff-hl-update-after-focus-change ()
    (cond ((bound-and-true-p diff-hl-mode)
           (diff-hl-update))
          ((bound-and-true-p diff-hl-dir-mode)
           (diff-hl-dir-update))
          ((bound-and-true-p diff-hl-dired-mode)
           (diff-hl-dired-update))
          (t t)))
  (add-function :after after-focus-change-function
                #'+diff-hl-update-after-focus-change)
  )


;; [with-editor] Lets git-invoked editors reuse this Emacs.  The GUI
;; Emacs.app here is a plain copy (no Contents/MacOS/bin/) and emacs-plus
;; is keg-only, so with-editor's own search cannot find emacsclient and
;; warns "Cannot determine a suitable Emacsclient" on first magit use.
;; Pre-seed it from the Homebrew opt path (stable across minor upgrades);
;; when nothing is found, leave the default so with-editor still falls
;; back to its sleeping editor.
(use-package with-editor
  :straight t
  :init
  (when-let* ((client
               (or (executable-find "emacsclient")
                   (seq-find #'file-executable-p
                             '("/opt/homebrew/opt/emacs-plus@31/bin/emacsclient"
                               "/opt/homebrew/opt/emacs-plus/bin/emacsclient"
                               "/usr/local/opt/emacs-plus@31/bin/emacsclient")))))
    (setq with-editor-emacsclient-executable client)))


;; [magit] Version control interface
(use-package magit
  :straight t
  :bind (("C-x g" . magit))
  :hook ((magit-process-mode . goto-address-mode))
  :config
  (setq
   ;; word-granularity refine (also required for abridge-diff impact)
   magit-diff-refine-hunk 'all
   ;; dont paint whitespace
   magit-diff-paint-whitespace nil
   ;; Don't autosave repo buffers. This is too magical
   magit-save-repository-buffers nil
   ;; Don't display parent/related refs in commit buffers; they are rarely helpful and only add to runtime costs.
   magit-revision-insert-related-refs nil
   magit-diff-use-indicator-faces t)

  ;; Exterminate Magit buffers
  (defun +magit-kill-buffers (&rest _)
    "Restore window configuration and kill all Magit buffers."
    (interactive)
    (magit-restore-window-configuration)
    (let ((buffers (magit-mode-get-buffers)))
      (when (eq major-mode 'magit-status-mode)
        (mapc (lambda (buf)
                (with-current-buffer buf
                  (if (and magit-this-process
                           (eq (process-status magit-this-process) 'run))
                      (bury-buffer buf)
                    (kill-buffer buf))))
              buffers))))
  (setq magit-bury-buffer-function #'+magit-kill-buffers)

  (defun +toggle-magit-difftastic ()
    "Toggle `magit-difftastic-mode' in Magit buffers."
    (interactive)
    (magit-difftastic-mode
     (if magit-difftastic-mode -1 1)))
  (transient-append-suffix 'magit-diff '(-1 -1)
    [("D" "Difftastic Diff" +toggle-magit-difftastic)])
  )


(use-package magit-difftastic
  :straight (:host github :repo "rschmukler/magit-difftastic")
  :after magit
  :config
  (setq magit-difftastic-display "inline"
        magit-difftastic-line-numbers nil
        magit-difftastic-syntax-highlight nil)
  )


(use-package forge
  :straight t
  :after magit
  :custom-face
  (forge-topic-label ((t (:inherit variable-pitch :height 0.9 :width condensed :weight regular :underline unspecified)))))
;; NOTE: `forge-topic-list-columns' was removed upstream; forge now only has
;; `forge-repository-list-columns'.  The old setting was dead configuration.

;; [magh.el] Magit-style GitHub frontend powered by the `gh' CLI.
;; Upstream github.com/roife/magh.el was DELETED (404). Source of truth is the
;; local backup clone (default ~/code/gh.el) → straight/repos/magh.el.
;; Override `+magh-git-repo' in gitignored `private.el'.  MERGE LOCK: do not
;; point the recipe at roife/magh.el. Prefer a private remote later and switch
;; :repo to HTTPS/SSH so rebuilds work off this machine.
;; Package-Requires Emacs 31.1+ (header); runs on 31.0.91 builds with care.
(defvar +magh-git-repo (expand-file-name "~/code/gh.el")
  "Local clone of magh.el (gh.el).  Override in `private.el'.")

(defmacro +magh-package (name &rest body)
  "Like `use-package' for magh NAME, cloning from `+magh-git-repo'."
  (declare (indent defun))
  `(use-package ,name
     :straight (:type git :repo ,+magh-git-repo :local-repo "magh.el")
     ,@body))

(+magh-package magh
  :bind (("C-, g g" . magh)
         ("C-, g G" . magh-dispatch)
         ("C-, g d" . magh-repo-status)
         ("C-, g D" . magh-repo-status-other)
         ("C-, g H" . magh-user-status)
         ("C-, g i" . magh-issue-list)
         ("C-, g p" . magh-pr-list)
         ("C-, g v" . magh-review-requests)
         ("C-, g w" . magh-run-list)
         ("C-, g e" . magh-release-list)
         ("C-, g /" . magh-search-dispatch)
         ("C-, g t" . magh-browse-repository)
         ("C-, g n" . magh-notifications-dispatch)
         ("C-, g r" . magh-command)
         ("C-, g a" . magh-api-request))
  :config
  (setq magh-list-limit 50
        magh-client-cache-ttl 30
        magh-confirm-destructive-actions t
        magh-notifications-unread-only t
        magh-notifications-group-by 'repository
        magh-view-inline-images t)

  ;; Keep user-maintained GitHub shortcuts across Emacs sessions.  savehist is
  ;; enabled from init-basic.el's after-init hook in non-daemon sessions.
  (with-eval-after-load 'savehist
    (dolist (variable '(magh-known-repositories
                        magh-favorite-organizations
                        magh-workflow-template-repositories))
      (add-to-list 'savehist-additional-variables variable))))


;; [magh-magit] Lightweight asynchronous magh.el summaries in Magit status
(+magh-package magh-magit
  :after magit
  :demand t
  :config
  (setq magh-magit-dispatch-key "@"
        magh-magit-status-sections '(pr issue run)
        magh-magit-summary-scope 'repository
        magh-magit-list-limit 10
        magh-magit-cache-ttl 30
        ;; Forge owns its PR and Issue sections; magh.el still shows Actions.
        magh-hide-forge-duplicates t)
  (magh-magit-mode 1))


;; Structured actions for magh.el candidates in Embark.
(+magh-package magh-embark
  :after embark
  :demand t
  :config
  (magh-embark-mode 1))


;; Keep magh.el's native Issue/PR viewer, with an explicit Forge -> magh.el bridge.
(+magh-package magh-forge
  :after forge
  :commands (magh-forge-open-current-topic-in-magh)
  :bind (:map forge-topic-mode-map
              ("C-c C-g" . magh-forge-open-current-topic-in-magh)))


;; Show TODOs in magit (`magit-todos-mode' is global; enable once).
(use-package magit-todos
  :straight t
  :after magit
  :config
  (magit-todos-mode 1))



;; [smerge] VC/Git already calls `smerge-start-session' on conflicts.
(use-package smerge-mode
  :preface
  (defun +smerge-try-smerge ()
    (when (and buffer-file-name
               (save-excursion
                 (goto-char (point-min))
                 (re-search-forward "^<<<<<<< " nil t))
               (vc-backend buffer-file-name))
      (require 'smerge-mode)
      (smerge-mode 1)))
  :hook (find-file . +smerge-try-smerge))


;; [browse-at-remote] Open github/gitlab/bitbucket page
(use-package browse-at-remote
  :straight t
  :bind (:map vc-prefix-map
              ("B" . browse-at-remote))
  )


;; [git-modes] Git configuration major modes
(use-package git-modes
  :straight t)


;; [abridge-diff] Global minor mode (not a magit-diff-visit-file buffer hook).
(use-package abridge-diff
  :straight t
  :after magit
  :config
  (abridge-diff-mode 1))
