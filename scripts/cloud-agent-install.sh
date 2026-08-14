#!/usr/bin/env bash
# Cloud Agent repository bootstrap for this Emacs configuration.
#
# Runs after the repository is checked out. It is idempotent: straight.el is
# configured with `straight-check-for-modifications nil', so re-running only
# verifies the already-built package tree instead of rebuilding it.
#
# Responsibilities:
#   * Make this checkout usable as `~/.emacs.d' so a plain `emacs' finds it.
#   * Create the ~/.config/emacs-cloud launcher profile used by `emacs-dev'.
#   * Bootstrap straight.el and build the pinned package tree
#     (straight/versions/default.el), tolerating the two packages that cannot
#     be built on Linux (see scripts/cloud-agent-bootstrap.el).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMACS_BIN="$(command -v emacs)"

echo "== cloud-agent-install: repo=${REPO_ROOT} emacs=${EMACS_BIN}"
"${EMACS_BIN}" --version | head -1

# Convenience: expose the checkout as ~/.emacs.d (only if free / already ours).
EMACSD="${HOME}/.emacs.d"
if [ -L "${EMACSD}" ] || [ ! -e "${EMACSD}" ]; then
  ln -sfn "${REPO_ROOT}" "${EMACSD}"
  echo "== linked ${EMACSD} -> ${REPO_ROOT}"
else
  echo "== ${EMACSD} already exists and is not a symlink; leaving it untouched"
fi

# Launcher profile for `emacs-dev'. Loading the config as the profile's
# user-init-file (rather than via `-l' after startup) ensures after-init-hook
# fires, so global modes such as vertico-mode/marginalia-mode activate.
PROFILE="${HOME}/.config/emacs-cloud"
mkdir -p "${PROFILE}"
cat > "${PROFILE}/early-init.el" <<'ELISP'
;;; -*- lexical-binding: t -*-
;; Cloud Agent launcher profile. Run the real config's early-init.el (keeping
;; its eln-cache under the repo) WITHOUT redirecting where Emacs looks for
;; init.el, so this profile's init.el remains the user-init-file.
(let ((user-emacs-directory
       (file-name-as-directory (expand-file-name "~/.emacs.d"))))
  (load (expand-file-name "early-init.el" user-emacs-directory) nil t))
ELISP
cat > "${PROFILE}/init.el" <<'ELISP'
;;; -*- lexical-binding: t -*-
;; Load the real init.el as the user-init-file (so after-init-hook fires and
;; global modes activate) via the resilient bootstrap loader, which tolerates
;; the packages that cannot be built on Linux.
(load (expand-file-name "~/.emacs.d/scripts/cloud-agent-bootstrap.el") nil t)
ELISP
echo "== wrote launcher profile ${PROFILE}"

# Bootstrap straight.el and build/native-compile the package tree.
echo "== bootstrapping straight.el and building packages (this may take a few minutes)"
"${EMACS_BIN}" --batch --init-directory="${REPO_ROOT}" \
  -l "${REPO_ROOT}/scripts/cloud-agent-bootstrap.el"

echo "== cloud-agent-install: done"
