#!/bin/sh
# Regression test: the config must load to the end of init.el in batch.
#
# Failure it pins (2026-11-21): `require init-theme' killed startup with
#   "Unable to find theme file for 'ashen-night'"
# because `init-theme' calls +load-theme immediately, while `use-package ashen'
# was only declared ~200 org lines later inside init-ui (never reached).
#
# Run: cd /Users/dragon/.config/emacs && sh scripts/test-init-load.sh
# Exit: 0 = all assertions pass, 1 = at least one failed.

set -u

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp "${TMPDIR:-/tmp}/init-load.XXXXXX")
trap 'rm -f "$out"' EXIT INT TERM

cd "$repo_dir" || exit 1

emacs -Q --batch -l early-init.el -l init.el \
      --eval '(princ "REACHED-END\n")' \
      --eval '(princ (format "THEMES=%S\n" custom-enabled-themes))' >"$out" 2>&1
status=$?

fail=0
check() { # check <PASS|FAIL> <description>
    if [ "$1" = PASS ]; then
        printf 'PASS  %s\n' "$2"
    else
        printf 'FAIL  %s\n' "$2"
        fail=1
    fi
}

if [ "$status" -eq 0 ]; then
    check PASS "exit code is 0 (got $status)"
else
    check FAIL "exit code is 0 (got $status)"
fi

if grep -qF 'REACHED-END' "$out"; then
    check PASS "output contains REACHED-END"
else
    check FAIL "output contains REACHED-END"
fi

if grep -qF 'Unable to find theme file' "$out"; then
    check FAIL "output does not contain 'Unable to find theme file'"
else
    check PASS "output does not contain 'Unable to find theme file'"
fi

if grep -qF 'Cannot open load file: ashen' "$out"; then
    check FAIL "output does not contain 'Cannot open load file: ashen'"
else
    check PASS "output does not contain 'Cannot open load file: ashen'"
fi

# Exit 0 alone cannot tell "theme loaded" from "theme silently skipped":
# assert the theme really is enabled.
if grep -qF 'THEMES=(ashen-night)' "$out"; then
    check PASS "ashen-night is enabled (THEMES=(ashen-night))"
else
    check FAIL "ashen-night is enabled (got: $(grep -o 'THEMES=.*' "$out" || echo 'no THEMES line'))"
fi

if [ "$fail" -ne 0 ]; then
    printf '\n--- emacs output (%s) ---\n' "$out"
    cat "$out"
    printf '\nRESULT: FAIL\n'
    exit 1
fi

printf '\nRESULT: PASS\n'
exit 0
