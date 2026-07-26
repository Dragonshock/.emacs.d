#!/usr/bin/env bash
# PostToolUse hook: sanity-check an edited Emacs Lisp file in this config.
#
# 1. Reader check   — unbalanced parens / invalid read syntax (hard error).
# 2. Byte-compile   — with init-util.el + init-straight.el preloaded so that
#                     `add-hook!` / `defadvice!` / `:straight` resolve.
#
# Byte-compiling a single module can't see the packages it configures, so most
# "free variable" / "Cannot load" output is a false positive. We whitelist only
# the warning classes that are real regardless of what's loaded.
set -uo pipefail

f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)
[ -n "${f:-}" ] || exit 0
case "$f" in
  *.el) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0

cfg="${CLAUDE_PROJECT_DIR:-$HOME/.emacs.d}"
case "$f" in
  "$cfg"/*) ;;
  *) exit 0 ;;
esac

EMACS="${EMACS:-}"
if [ -z "$EMACS" ] || ! [ -x "$EMACS" ]; then
  for c in "$(command -v emacs 2>/dev/null)" \
           /Applications/Emacs.app/Contents/MacOS/Emacs \
           /opt/homebrew/bin/emacs /usr/local/bin/emacs; do
    [ -n "$c" ] && [ -x "$c" ] && EMACS="$c" && break
  done
fi
[ -n "$EMACS" ] || exit 0

report() {
  jq -n --arg ctx "$1" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
  exit 0
}

# --- 1. paren-balance check ------------------------------------------------
# `check-parens' understands comments and strings; a naive `read' loop trips
# over the trailing `;;; foo.el ends here' comment most modules have.
read_err=$("$EMACS" -Q --batch --eval "(condition-case e
    (with-temp-buffer
      (insert-file-contents \"$f\")
      (emacs-lisp-mode)
      (check-parens))
  (error (princ (format \"%s\" (error-message-string e))) (kill-emacs 1)))" 2>&1)
if [ $? -ne 0 ]; then
  report "elisp-check: $f 括号不匹配或读取语法错误——启动会直接失败。
$(printf '%s\n' "$read_err" | grep -v '^Mark set$')"
fi

# --- 2. filtered byte-compile ---------------------------------------------
out=$("$EMACS" -Q --batch \
        -l "$cfg/core/init-util.el" \
        -l "$cfg/core/init-straight.el" \
        --eval '(setq byte-compile-dest-file-function
                      (lambda (src) (expand-file-name
                                     (concat (file-name-nondirectory src) "c")
                                     temporary-file-directory)))' \
        -f batch-byte-compile "$f" 2>&1)

# Kept: warning classes that hold regardless of which packages are loaded.
# Dropped as noise: "free variable" / "not known to be defined" / "Cannot load"
# (deferred packages aren't present in batch); "defined multiple times"
# (use-package's deferred expansion emits `:init' defuns twice); "Unused
# lexical variable" (let-binding a package's defvar looks lexical in batch).
hits=$(printf '%s\n' "$out" | grep -E \
  'called with [0-9]+ argument|Unused lexical argument|is an obsolete|Invalid read syntax|malformed|Invalid function' \
  || true)

[ -n "$hits" ] || exit 0
report "elisp-check ($(basename "$f")) — 单文件字节编译发现（可能是既有问题，不一定来自本次改动）：
$hits

（已过滤包未加载导致的假阳性。最终以完整启动验证为准：/verify-init）"
