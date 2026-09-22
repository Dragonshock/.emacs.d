;;; init-lexdb.el --- Multi-dictionary lookup via lexdb -*- lexical-binding: t -*-

;;; Commentary:
;; LexDB: SQLite-backed LDOCE / OALD / ODE lookup.
;; Data lives under `+lexdb-data-dir' (outside this config tree).
;; Bindings reuse the old dictionary keys: C-c d d (at point), C-c d s (prompt).
;; C-c d i remains consult-imenu.
;;
;; Audio: prefers mpv (local files and URLs).  Install with `brew install mpv`.
;; GUI Emacs often misses Homebrew PATH, so `/opt/homebrew/bin/mpv` is checked.

;;; Code:

(defvar +lexdb-data-dir
  (expand-file-name "~/Documents/40-词典/词库源/lexdb")
  "Directory holding lexdb SQLite databases and optional audio.")

(use-package lexdb
  :straight (:host github :repo "Dragonshock/lexdb" :files ("*.el"))
  :commands (lexdb-search lexdb-search-at-point)
  :bind (("C-c d d" . lexdb-search-at-point)
         ("C-c d s" . lexdb-search))
  :init
  (setq lexdb-multi-dict-mode t
        lexdb-ui-translation-display 'peek
        lexdb-audio-player (or (executable-find "mpv")
                               (and (file-executable-p "/opt/homebrew/bin/mpv")
                                    "/opt/homebrew/bin/mpv")
                               (executable-find "ffplay")
                               (and (file-executable-p "/opt/homebrew/bin/ffplay")
                                    "/opt/homebrew/bin/ffplay")
                               "mpv")
        lexdb-dictionaries
        `((:id ldoce :type ldoce :name "朗文当代"
           :db-file ,(expand-file-name "sqlite/LDOCE6.db" +lexdb-data-dir)
           :priority 1)
          (:id oald :type oald :name "牛津双解"
           :db-file ,(expand-file-name "sqlite/OALD4_EC.db" +lexdb-data-dir)
           :priority 2)
          (:id ode :type ode :name "牛津英语"
           :db-file ,(expand-file-name "sqlite/ODE_Living_Online.db" +lexdb-data-dir)
           :priority 3)))
  :config
  (require 'lexdb-ui)
  (require 'lexdb-ldoce)
  (require 'lexdb-oald)
  (require 'lexdb-ode)
  (lexdb-init))

(provide 'init-lexdb)
;;; init-lexdb.el ends here
