;;; -*- lexical-binding: t -*-

;; Batch checks for Pi's Magpie model id.  Run from the repo root:
;;   emacs -Q --batch -l scripts/test-agent-shell-magpie.el

(defvar +test-failures nil)

(defmacro +test (name &rest body)
  `(let ((err (condition-case e
                  (progn ,@body nil)
                (error e))))
     (if err
         (progn (push ,name +test-failures)
                (princ (format "FAIL %s: %S\n" ,name err)))
       (princ (format "PASS %s\n" ,name)))))

(defun +agent-shell-pi-model-id (model)
  "Prefix MODEL with magpie/ unless it already names that provider.
Pi treats the text before the first slash as the provider."
  (let ((name (if (symbolp model) (symbol-name model) model)))
    (if (string-prefix-p "magpie/" name)
        name
      (concat "magpie/" name))))

(+test "picker id keeps its own slashes after the provider"
  (unless (equal (+agent-shell-pi-model-id "workbuddy/auto")
                 "magpie/workbuddy/auto")
    (error "got %s" (+agent-shell-pi-model-id "workbuddy/auto"))))

(+test "routing group symbol is sent through magpie"
  (unless (equal (+agent-shell-pi-model-id 'group/smart-split)
                 "magpie/group/smart-split")
    (error "got %s" (+agent-shell-pi-model-id 'group/smart-split))))

(+test "an id that already names magpie is unchanged"
  (unless (equal (+agent-shell-pi-model-id "magpie/group/smart-split")
                 "magpie/group/smart-split")
    (error "got %s" (+agent-shell-pi-model-id "magpie/group/smart-split"))))

(defconst +repo (expand-file-name ".." (file-name-directory load-file-name)))

(+test "agent-shell pi follows the magpie picker"
  (let ((text (with-temp-buffer
                (insert-file-contents (expand-file-name "core/init-ai.el" +repo))
                (buffer-string))))
    (unless (string-search "agent-shell-agent-configs '(+agent-shell-pi-make-agent-config)" text)
      (error "pi config maker was not wrapped"))
    (unless (string-match-p "agent-shell-preferred-agent-config 'pi" text)
      (error "preferred agent is no longer pi"))
    (unless (string-match-p ":default-model-id" text)
      (error "default model is not set"))
    (unless (string-match-p "\\+gptel-magpie-model" text)
      (error "picker reader is gone"))
    (unless (string-match-p "(defun \\+agent-shell-pi-model-id" text)
      (error "model id helper missing"))))

(when +test-failures
  (kill-emacs 1))
