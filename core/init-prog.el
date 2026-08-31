;;; -*- lexical-binding: t -*-

;; [compile]
(use-package compile
  :preface
  (eval-when-compile
    (require 'cl-lib)
    (require 'compile))

  (defvar +compilation-flymake-diagnostics nil
    "Flymake diagnostics parsed from the latest compilation buffer.")

  (defun +compilation-flymake--file (location)
    "Return the file named by compilation LOCATION."
    (let* ((file-struct (compilation--loc->file-struct location))
           (file-spec (compilation--file-struct->file-spec file-struct))
           (file (car file-spec)))
      (if (bufferp file)
          (buffer-file-name file)
        (compilation--expand-fn
         (or (cadr file-spec) default-directory)
         (format (or (car (compilation--file-struct->formats file-struct))
                     "%s")
                 file)))))

  (defun +compilation-flymake--message-start (message position)
    "Return the beginning of parsed MESSAGE around POSITION.
Compilation text properties may cover only a hyperlink inside the full
parser match, so recover the complete match from MESSAGE's parser rule."
    (let* ((rule (compilation--message->rule message))
           (item (and rule
                      (cdr (assq rule compilation-error-regexp-alist-alist))))
           (regexp (car-safe item)))
      (or (and (stringp regexp)
               (save-excursion
                 (goto-char position)
                 (end-of-line)
                 (when (and (re-search-backward regexp nil t)
                            (<= (match-beginning 0) position)
                            (<= position (match-end 0)))
                   (match-beginning 0))))
          (save-excursion
            (goto-char position)
            (line-beginning-position)))))

  (defun +compilation-flymake--collect ()
    "Convert the current compilation buffer's parsed message cache."
    (save-excursion
      (let ((entries
             (progn
               (goto-char (point-min))
               (cl-loop
                with seen = (make-hash-table :test #'eq)
                for match = (text-property-search-forward
                             'compilation-message nil nil t)
                while match
                for message = (prop-match-value match)
                for location = (compilation--message->loc message)
                for type = (compilation--message->type message)
                for position = (+compilation-flymake--message-start
                                message (prop-match-beginning match))
                ;; Informational locations usually provide context for the
                ;; preceding warning or error, rather than a separate
                ;; diagnostic.  Keep them in that diagnostic's text range.
                unless (or (zerop type) (gethash message seen))
                collect (progn
                          (puthash message t seen)
                          (vector location type position))))))
        (cl-loop
         for tail on entries
         for entry = (car tail)
         for next = (cadr tail)
         for location = (aref entry 0)
         for type = (aref entry 1)
         for position = (aref entry 2)
         for end = (if next (aref next 2) (point-max))
         collect
         (flymake-make-diagnostic
          (+compilation-flymake--file location)
          (cons (or (compilation--loc->line location) 1)
                (compilation--loc->col location))
          nil
          (if (= type 1) 'flymake-warning 'flymake-error)
          (save-excursion
            (goto-char position)
            (string-trim
             (buffer-substring-no-properties
              (line-beginning-position) end)))
          '+compilation-flymake)))))

  (defun +compilation-flymake--publish-project-diagnostics ()
    "Replace Compilation-owned project diagnostics."
    (setq flymake-list-only-diagnostics
          (cl-loop for (file . diagnostics) in flymake-list-only-diagnostics
                   for others = (cl-remove '+compilation-flymake diagnostics
                                           :key #'flymake-diagnostic-data)
                   when others collect (cons file others)))
    (dolist (diagnostic +compilation-flymake-diagnostics)
      (push diagnostic
            (alist-get (flymake-diagnostic-buffer diagnostic)
                       flymake-list-only-diagnostics nil nil #'equal))))

  (defun +compilation-flymake-backend (report-fn &rest _args)
    "Report compilation diagnostics belonging to the current buffer.
Diagnostics for all files are published separately for project listings."
    (let (diagnostics)
      (dolist (cached +compilation-flymake-diagnostics)
        (when (and buffer-file-name
                   (file-equal-p buffer-file-name
                                 (flymake-diagnostic-buffer cached)))
          (when-let* ((position (flymake-diagnostic-beg cached))
                      (region (flymake-diag-region
                               (current-buffer)
                               (car position) (cdr position))))
            (push (flymake-make-diagnostic
                   (current-buffer) (car region) (cdr region)
                   (flymake-diagnostic-type cached)
                   (flymake-diagnostic-message cached))
                  diagnostics))))
      (funcall report-fn (nreverse diagnostics))))

  (defun +compilation-flymake-finish-h (buffer _status)
    "Publish the parsed messages from compilation BUFFER."
    (require 'flymake)
    (let ((old-files (mapcar #'flymake-diagnostic-buffer
                             +compilation-flymake-diagnostics)))
      (setq +compilation-flymake-diagnostics
            (with-current-buffer buffer
              (+compilation-flymake--collect)))
      (+compilation-flymake--publish-project-diagnostics)
      (dolist (file (delete-dups
                     (append old-files
                             (mapcar #'flymake-diagnostic-buffer
                                     +compilation-flymake-diagnostics))))
        (when-let* ((source (find-buffer-visiting file)))
          (with-current-buffer source
            (when flymake-mode
              (flymake-start)))))))

  :config
  (setq compilation-always-kill t       ; kill compilation process before starting another
        compilation-ask-about-save nil  ; save all buffers on `compile'
        compilation-scroll-output 'first-error)

  ;; Automatically truncate compilation buffers so they don't accumulate too
  ;; much data and bog down the rest of Emacs.
  (autoload 'comint-truncate-buffer "comint" nil t)
  (add-hook! compilation-filter-hook
    (defun +compilation--truncate-buffer-h (&optional _string)
      "Rate-limit `comint-truncate-buffer' in compilation buffers."
      (require 'comint)
      (when (> (buffer-size)
               (* 80 comint-buffer-maximum-size))
        (let ((gc-cons-threshold most-positive-fixnum)
              (gc-cons-percentage 1.0))
          (with-silent-modifications
            (comint-truncate-buffer))))))

  ;; Emacs 28+: stock filter (respects `ansi-color-for-compilation-mode').
  (add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)
  (add-hook 'compilation-finish-functions #'+compilation-flymake-finish-h)
  )


;; [comment]
;; comment over empty lines
(setq comment-empty-lines t)


;; [xref] Cross reference
(use-package xref
  :config
  (setq
   xref-search-program 'ripgrep
   ;; TODO: https://github.com/oantolin/embark/issues/162#issuecomment-785039305
   ;; Maybe a bug?
   ;; xref-show-definitions-function #'xref-show-definitions-completing-read
   ;; xref-show-xrefs-function #'xref-show-definitions-completing-read
   xref-history-storage 'xref-window-local-history)

  (defadvice! +xref--push-marker-stack-a (&rest rest)
    :before '(find-function consult-imenu consult-ripgrep citre-jump)
    (xref-push-marker-stack (point-marker)))
  )


;; [Eglot] LSP support
(use-package eglot
  :straight (:type built-in)
  :commands (eglot eglot-ensure)
  :preface
  (defconst +eglot-auto-start-modes
    '(c-mode c++-mode rust-mode python-mode java-mode
             c-ts-mode c++-ts-mode rust-ts-mode python-ts-mode java-ts-mode)
    "Major modes where Eglot should start automatically.")
  :init
  (dolist (mode +eglot-auto-start-modes)
    (add-hook (intern (format "%s-hook" mode)) #'eglot-ensure))
  :custom-face (eglot-highlight-symbol-face ((t (:underline t))))
  :bind (:map eglot-mode-map
              ("M-<return>" . eglot-code-actions)
              ("M-/" . eglot-find-typeDefinition)
              ("M-?" . xref-find-references))
  :config
  ;; Keep local Flymake backends (hl-todo, compilation); add Eglot's per buffer.
  (add-to-list 'eglot-stay-out-of 'flymake-diagnostic-functions)

  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-autoshutdown t
        ;; eglot-report-progress 'messages
        eglot-code-action-indications nil)
  ;; Renderer needs a bound major mode; markdown-ts-view-mode is not autoloaded.
  (require 'markdown-ts-mode nil t)
  (setq eglot-documentation-renderer
        (if (fboundp 'markdown-ts-view-mode)
            'markdown-ts-view-mode
          'gfm-view-mode))

  ;; Eldoc strategy / disable is set in `+eglot-managed-mode-h' (buffer-local).
  ;; Flat plist (not alist of sections); RA uses :features "all", not "full"/:allFeatures.
  ;; Client ECC belongs in CONTACT :initializationOptions, not workspace/configuration.
  (setq-default eglot-workspace-configuration
                ;; Prefer pylsp section name (pyls is the deprecated Palantir server).
                ;; Flat plist per eglot docstring (alist is less reliable).
                ;; Backquote: Java runtime paths come from the environment.
                `(:pylsp (:plugins (:jedi_completion (:fuzzy t)))
                         :rust-analyzer (:cargo (:allTargets t :features "all")
                                                :checkOnSave :json-false
                                                :completion (:termSearch (:enable t)
                                                                         :fullFunctionSignatures (:enable t))
                                                :hover (:memoryLayout (:size "both")
                                                                      :show (:traitAssocItems 5)
                                                                      :documentation (:keywords (:enable :json-false)))
                                                :inlayHints (:lifetimeElisionHints (:enable "skip_trivial" :useParameterNames t)
                                                                                   :closureReturnTypeHints (:enable "always")
                                                                                   :discriminantHints (:enable t)
                                                                                   :genericParameterHints (:lifetime (:enable t)))
                                                :semanticHighlighting (:operator (:specialization (:enable t))
                                                                                 :punctuation (:enable t :specialization (:enable t)))
                                                :workspace (:symbol (:search (:kind "all_symbols"
                                                                                    :scope "workspace_and_dependencies")))
                                                :references (:excludeImports t
                                                                             :excludeTests t)
                                                :lru (:capacity 1024)
                                                :diagnostics (:enable :json-false))
                         ;; typescript preferences belong in CONTACT :initializationOptions
                         ;; (workspace/configuration does not feed tsserver preferences).
                         :java (:configuration
                                (:runtimes [(:name "JavaSE-21"
                                                   :path ,(getenv "JAVA21_HOME")
                                                   :default t)
                                            (:name "JavaSE-26"
                                                   :path ,(getenv "JAVA26_HOME"))])
                                :import (:gradle (:enabled t
                                                           :wrapper (:enabled t)))
                                :autobuild (:enabled :json-false))))

  ;; typescript-language-server: import preference via initialize options only.
  (add-to-list 'eglot-server-programs
               `(((js-mode :language-id "javascript")
                  (js-ts-mode :language-id "javascript")
                  (tsx-ts-mode :language-id "typescriptreact")
                  (typescript-ts-mode :language-id "typescript")
                  (typescript-mode :language-id "typescript"))
                 . ("typescript-language-server" "--stdio"
                    :initializationOptions
                    (:preferences (:importModuleSpecifierPreference "non-relative")))))

  (defun jdtls-command-contact (&optional _interactive)
    "Eglot CONTACT for jdtls; ECC goes in :initializationOptions (not workspace config)."
    (let* ((jdtls-java-home (getenv "JDTLS_JAVA_HOME"))
           (project-root (project-root (project-current t)))
           (data-dir
            (file-name-concat
             (no-littering-expand-var-file-name "lsp-cache/")
             (md5 (expand-file-name project-root))))
           (init-opts
            '(:extendedClientCapabilities (:classFileContentsSupport t))))
      ;; Only inject JAVA_HOME when set; bare "JAVA_HOME=" clears the child env.
      (if (and jdtls-java-home (not (string-empty-p jdtls-java-home)))
          `("env" ,(concat "JAVA_HOME=" jdtls-java-home)
            "jdtls" "--jvm-arg=-Xmx16G" "-data" ,data-dir
            :initializationOptions ,init-opts)
        `("jdtls" "--jvm-arg=-Xmx16G" "-data" ,data-dir
          :initializationOptions ,init-opts))))
  (add-to-list 'eglot-server-programs
               `((java-mode java-ts-mode) . ,#'jdtls-command-contact))

  (add-hook! eglot-managed-mode-hook
    (defun +eglot-managed-mode-h ()
      "Install or remove Flymake/Eldoc integrations as Eglot starts or stops."
      ;; Drop treesit/CC Flymake backends so they do not compete with Eglot.
      (dolist (backend '(rust-ts-flymake flymake-cc python-flymake))
        (remove-hook 'flymake-diagnostic-functions backend t))
      (if (eglot-managed-p)
          (progn
            (add-hook 'flymake-diagnostic-functions #'eglot-flymake-backend nil t)
            (setq-local eldoc-documentation-strategy
                        'eldoc-documentation-compose-eagerly)
            (eldoc-mode -1))
        (remove-hook 'flymake-diagnostic-functions #'eglot-flymake-backend t)
        (when flymake-mode
          (flymake-start)))))
  )


(use-package eglot-tempel
  :straight t
  :after (eglot tempel)
  :config
  (eglot-tempel-mode 1))


;; eglot-booster: upstream archived; Emacs 30/31 JSON is fast enough without it.


;; [Eldoc]
(use-package eldoc
  :bind (("C-h h" . eldoc))
  :config
  (setq eldoc-echo-area-prefer-doc-buffer t
        eldoc-echo-area-use-multiline-p nil
        eglot-extend-to-xref t)
  ;; Has a :set function that wires `eldoc-show-help-at-pt' into
  ;; `eldoc-documentation-functions'; plain setq is a silent no-op.
  (setopt eldoc-help-at-pt t))


;; [help]
(use-package help
  :bind (("s-?" . display-local-help)))


;; [consult-eglot] Eglot support for consult
(use-package consult-eglot
  :after consult eglot
  :straight t
  :bind (:map eglot-mode-map
              ([remap xref-find-apropos] . consult-eglot-symbols)))


;; [webpaste] Web Pastebin
(use-package webpaste
  :straight t
  :commands webpaste-paste-buffer-or-region
  :config
  ;; webpaste-add-to-killring package default is already t.
  (setq webpaste-paste-confirmation t
        webpaste-provider-priority '("paste.rs")))


;; [dumb-jump] Jump to definition (integrated with xref, a fallback of lsp)
(use-package dumb-jump
  :straight t
  :init
  (add-hook! xref-backend-functions #'dumb-jump-xref-activate)
  :config
  ;; `dumb-jump-selector' only affects legacy dumb-jump-go*; we use xref only.
  (setq dumb-jump-prefer-searcher 'rg
        dumb-jump-aggressive t
        dumb-jump-default-project user-emacs-directory)
  )


;; [citre] Ctags-infra
(use-package citre
  :straight t
  :commands (citre-update-this-tags-file)
  :bind (:map prog-mode-map
              ("C-c c j" . +citre-jump)
              ("C-c c k" . +citre-jump-back)
              ("C-c c p" . citre-peek)
              ("C-c c a" . citre-ace-peek)
              ("C-c c u" . citre-update-this-tags-file))
  :hook ((prog-mode . citre-auto-enable-citre-mode))
  :config
  (require 'dumb-jump)
  (citre-register-backend 'dumb-jump
                          (citre-xref-backend-to-citre-backend
                           'dumb-jump #'dumb-jump-xref-activate))
  (setq citre-default-create-tags-file-location 'global-cache
        citre-edit-ctags-options-manually t
        citre-auto-enable-citre-mode-modes '(prog-mode)
        citre-find-definition-backends '(eglot tags global dumb-jump)
        citre-find-reference-backends '(eglot global dumb-jump))
  (setq-default citre-enable-xref-integration nil
                citre-enable-capf-integration t)

  (with-eval-after-load 'cc-mode (require 'citre-lang-c))
  (with-eval-after-load 'dired (require 'citre-lang-fileref))
  (with-eval-after-load 'verilog-mode (require 'citre-lang-verilog))

  (defun +citre-jump ()
    "Jump to the definition of the symbol at point. Fallback to `xref-find-definitions'."
    (interactive)
    (condition-case _
        (citre-jump)
      (error (call-interactively #'xref-find-definitions))))

  (defun +citre-jump-back ()
    "Go back to the position before last `citre-jump'. Fallback to `xref-go-back'."
    (interactive)
    (condition-case _
        (citre-jump-back)
      (error (call-interactively #'xref-go-back))))
  )


;; [quickrun] Run commands quickly
(use-package quickrun
  :straight t
  :config
  (setq quickrun-focus-p nil))


;; [dape] Debug Adapter Protocol client
(use-package dape
  :straight t
  :commands (dape)
  :bind (:map prog-mode-map
              ("C-c D" . dape))
  :preface
  (defun +dape-save-buffers-h ()
    "Save file-visiting buffers before starting a debug session."
    (save-some-buffers t t))
  :init
  (setq dape-buffer-window-arrangement 'right)
  :config
  (add-hook! dape-start-hook #'+dape-save-buffers-h))


;; [flymake] On-the-fly syntax checker
(use-package flymake
  :straight (:type built-in)
  :preface
  (defun +flymake-show-buffer-diagnostics-single-a (args)
    "Pass at most one diagnostic to `flymake-show-buffer-diagnostics'.
Emacs 31's interactive form returns every diagnostic at point as a
separate argument, although the command accepts only one."
    (if (cdr args) (list (car args)) args))

  (defun +flymake-add-shared-backends-h ()
    "Add buffer-local shared Flymake backends (hl-todo, compilation)."
    (dolist (backend '(hl-todo-flymake +compilation-flymake-backend))
      (add-hook 'flymake-diagnostic-functions backend nil t)))

  (defun +flymake-mode-unless-eglot-auto-starts ()
    "Enable Flymake unless Eglot will enable it after connecting.
Shared backends are still registered so Eglot-managed buffers keep them.
On Eglot auto-start modes, drop native treesit/CC backends first so an
asynchronous checker cannot report after Eglot has taken over
(notably `rust-ts-flymake'; upstream 874f89e)."
    (when (memq major-mode +eglot-auto-start-modes)
      (dolist (backend '(rust-ts-flymake flymake-cc python-flymake))
        (remove-hook 'flymake-diagnostic-functions backend t)))
    (+flymake-add-shared-backends-h)
    (unless (memq major-mode +eglot-auto-start-modes)
      (flymake-mode 1)))

  :hook ((prog-mode . +flymake-mode-unless-eglot-auto-starts))
  :bind (("C-c f ]" . flymake-goto-next-error)
         ("C-c f [" . flymake-goto-prev-error)
         ("C-c f b" . flymake-show-buffer-diagnostics)
         ("C-c f p" . flymake-show-project-diagnostics)
         :map flymake-mode-map
         ("<left-fringe> <mouse-1>" . nil)
         ("<right-fringe> <mouse-1>" . nil))
  :config
  (advice-add 'flymake-show-buffer-diagnostics :filter-args
              #'+flymake-show-buffer-diagnostics-single-a)
  (setq flymake-show-diagnostics-at-end-of-line 'short))

;; Langs
(use-package cc-mode
  :config
  (setq c-basic-offset 4)
  (c-set-offset 'case-label '+))

;; treesit C/C++ ignore `c-basic-offset'; use `c-ts-indent-offset' (default 2).
(use-package c-ts-mode
  :straight (:type built-in)
  :when (treesit-available-p)
  :config
  (setopt c-ts-indent-offset 4))


(use-package csv-mode
  :straight t)


(use-package rainbow-csv
  :straight (:host github :repo "emacs-vs/rainbow-csv"))


(use-package rmsbolt
  :straight t)


(use-package llvm-mode
  :straight (:host github :repo "nverno/llvm-mode" :files ("*.el")))


(use-package js
  :config
  (setq js-indent-level 2))


(use-package css-mode
  :config
  (setq css-indent-offset 2))


;; Classic rust-mode kept as dependency/fallback; .rs remaps to rust-ts-mode.
(use-package rust-mode
  :straight t
  :init
  (setq rust-format-goto-problem nil)
  :config
  (with-eval-after-load 'dtrt-indent
    (setf (alist-get 'rust-mode dtrt-indent-hook-mapping-list)
          '(c/c++/java rust-ts-indent-offset))))


(use-package fish-mode
  :straight t)


(use-package rust-playground
  :straight t)


(use-package verilog-mode
  :straight (:type built-in)
  :config
  (setq verilog-align-ifelse t
        verilog-auto-delete-trailing-whitespace t
        verilog-auto-inst-param-value t
        verilog-auto-inst-vector nil
        verilog-auto-lineup (quote all)
        verilog-auto-newline nil
        verilog-auto-save-policy nil
        verilog-auto-template-warn-unused t
        verilog-case-indent 4
        verilog-cexp-indent 4
        verilog-highlight-grouping-keywords t
        verilog-highlight-modules t
        verilog-indent-level 4
        verilog-indent-level-behavioral 4
        verilog-indent-level-declaration 4
        verilog-indent-level-module 4
        verilog-tab-to-comment t))


;; [yaml] third-party fallback; treesit remaps to yaml-ts-mode when available.
(use-package yaml-mode
  :straight t)


;; [toml] Use built-in conf-toml-mode / toml-ts-mode (treesit remaps).
;; Do not install third-party toml-mode — it steals auto-mode from treesit.


;; [graphviz-dot]
(use-package graphviz-dot-mode
  :straight t
  :config
  (setq graphviz-dot-indent-width 4))


;; Major mode for editing web templates
(use-package web-mode
  :straight t
  :mode "\\.[px]?html?\\'"
  :mode "\\.\\(?:tpl\\|blade\\)\\(?:\\.php\\)?\\'"
  :mode "\\.erb\\'"
  :mode "\\.[lh]?eex\\'"
  :mode "\\.jsp\\'"
  :mode "\\.as[cp]x\\'"
  :mode "\\.ejs\\'"
  :mode "\\.hbs\\'"
  :mode "\\.mustache\\'"
  :mode "\\.svelte\\'"
  :mode "\\.twig\\'"
  :mode "\\.jinja2?\\'"
  :mode "\\.eco\\'"
  :mode "wp-content/themes/.+/.+\\.php\\'"
  :mode "templates/.+\\.php\\'"
  :config
  (setq
   web-mode-markup-indent-offset 2
   web-mode-css-indent-offset 2
   web-mode-code-indent-offset 2
   web-mode-enable-html-entities-fontification t)
  ;; web-mode defaults six enable-* options with STANDARD (display-graphic-p).
  ;; Daemon + use-package-always-demand loads the package with no GUI frame, so
  ;; those STANDARD forms become nil and stick. Force GUI-friendly defaults
  ;; here (and refresh when a graphic client frame appears).
  (defun +web-mode-force-graphic-defaults ()
    "Set web-mode interactive defaults as if loaded under a graphic frame."
    (setq web-mode-enable-css-colorization t
          web-mode-enable-auto-indentation t
          web-mode-enable-auto-closing t
          web-mode-enable-auto-pairing t
          web-mode-enable-auto-opening t
          web-mode-enable-auto-quoting t))
  (+web-mode-force-graphic-defaults)
  (add-hook 'server-after-make-frame-hook
            (lambda ()
              (when (display-graphic-p)
                (+web-mode-force-graphic-defaults)))))


;; [treesit]
(use-package treesit
  :when (treesit-available-p)
  :init
  ;; `treesit-enabled-modes' MUST be set with `setopt': its :set function is
  ;; what installs the 26 entries of `treesit-major-mode-remap-alist' into
  ;; `major-mode-remap-alist'.  Plain `setq' silently does nothing.
  ;;
  ;; `require' remains load-bearing during early init while early-init's
  ;; temporary setopt advice inhibits custom-load-symbol (removed at
  ;; emacs-startup-hook).
  (require 'treesit)
  (setopt treesit-enabled-modes t
          ;; Also has a :set (`treesit--font-lock-level-setter'); setq is not enough.
          treesit-font-lock-level 4)
  (setq treesit-auto-install-grammar 'always))


;; Emacs 31: copy jq-style path of the JSON node at point.
(use-package json-ts-mode
  :when (treesit-available-p)
  :bind (:map json-ts-mode-map
              ("C-c C-j" . json-ts-jq-path-at-point)))


;; [indent-bars] Show indent guides
(use-package indent-bars
  :straight (indent-bars :type git :host github :repo "jdtsmith/indent-bars")
  :hook (prog-mode . indent-bars-mode)
  :config
  ;; Prevent terminal display properties from leaking into inserted text.
  (setf (alist-get 'indent-bars-display
                   (default-value 'text-property-default-nonsticky))
        t)
  (setq indent-bars-display-on-blank-lines nil
        indent-bars-depth-update-delay 0.15
        indent-bars-width-frac 0.1
        indent-bars-color '(highlight :face-bg t :blend 0.2)
        indent-bars-highlight-current-depth nil
        indent-bars-pattern ".")

  (add-hook! enable-theme-functions #'indent-bars-reset))


;; [direnv] Buffer-local project environments
(use-package envrc
  :straight t
  :hook (emacs-startup . envrc-global-mode))


;; [log-view-mode]
(use-package logview
  :straight t
  :custom
  (logview-additional-level-mappings
   '(("Pipeline levels" . ((error       "ERROR")
                           (warning     "WARN ")
                           (information "INFO ")
                           (debug       "DEBUG")
                           (trace       "TRACE")))))
  (logview-additional-submodes
   '(("Pipeline" . ((format . "[TIMESTAMP] [LEVEL] [NAME] MESSAGE")
                    (levels . "Pipeline levels"))))))


;; [minuet-ai] AI-powered inline code completion
;; Audit: do NOT global-hook minuet-auto-suggestion-mode on prog-mode —
;; default context posts buffer slices to DeepSeek (privacy P0; roife same-bad).
;; Opt-in: M-i minibuffer complete, or M-x minuet-auto-suggestion-mode.
(use-package minuet
  :straight (:host github :repo "milanglacier/minuet-ai.el")
  :bind (("M-i" . #'minuet-complete-with-minibuffer)
         :map minuet-active-mode-map
         ("M-p" . #'minuet-previous-suggestion)
         ("M-n" . #'minuet-next-suggestion)
         ("C-e" . #'minuet-accept-suggestion)
         ("C-g" . #'minuet-dismiss-suggestion))
  :custom-face
  (minuet-suggestion-face ((t (:inherit font-lock-comment-face :slant italic :weight normal :underline nil))))
  :config
  (setq minuet-provider 'openai-fim-compatible)

  (plist-put minuet-openai-fim-compatible-options :end-point "https://api.deepseek.com/beta/completions")
  (plist-put minuet-openai-fim-compatible-options :model "deepseek-v4-flash")
  (plist-put minuet-openai-fim-compatible-options :name "Deepseek")
  (plist-put minuet-openai-fim-compatible-options :api-key
             (lambda ()
               (require 'gptel)
               (gptel-api-key-from-auth-source "api.deepseek.com" "apikey")))

  (minuet-set-optional-options minuet-openai-fim-compatible-options :max_tokens 56)
  (minuet-set-optional-options minuet-openai-fim-compatible-options :top_p 0.9)

  ;; If auto mode is enabled manually, still never FIM on credential paths.
  ;; block-predicates only gate minuet--maybe-show-suggestion (auto path).
  (add-to-list 'minuet-auto-suggestion-block-predicates
               (lambda ()
                 (and buffer-file-name
                      (fboundp '+secret-file-p)
                      (+secret-file-p buffer-file-name))))

  ;; Manual paths (M-i / minuet-show-suggestion) ignore block-predicates —
  ;; refuse secret files so buffer context is never POSTed to the provider.
  (defun +minuet-refuse-secret-context (&rest _)
    "Abort minuet when the current buffer is a secret file."
    (when (and buffer-file-name
               (fboundp '+secret-file-p)
               (+secret-file-p buffer-file-name))
      (user-error "minuet: refused on secret file")))
  (advice-add 'minuet-complete-with-minibuffer :before #'+minuet-refuse-secret-context)
  (advice-add 'minuet-show-suggestion :before #'+minuet-refuse-secret-context))
