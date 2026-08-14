# Cloud Agent base image for this Emacs configuration.
#
# Ubuntu ships Emacs 29, but this configuration targets Emacs 30+ (for example
# init-edit.el calls `kill-ring-deindent-mode', new in Emacs 30). So we build
# Emacs 30.x from source with native compilation, tree-sitter, dynamic modules
# and a GTK3/X11 GUI, plus the external tools the config shells out to
# (ripgrep, fd, mpv, ffmpeg, exiftool, universal-ctags, isync, enchant for
# jinx, and difftastic for magit-difftastic).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ARG EMACS_VERSION=30.2
ARG DIFFT_VERSION=0.70.0

# Build toolchain + Emacs build dependencies + runtime tools used by the config.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git \
      build-essential autoconf automake texinfo pkg-config \
      libgtk-3-dev libgnutls28-dev libjansson-dev libgccjit-13-dev \
      libtree-sitter-dev libncurses-dev libxml2-dev \
      libtiff-dev libgif-dev libjpeg-dev libpng-dev libxpm-dev libwebp-dev \
      librsvg2-dev libsqlite3-dev libgpm-dev libsystemd-dev \
      ripgrep fd-find mpv ffmpeg libimage-exiftool-perl universal-ctags isync \
      enchant-2 libenchant-2-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and install Emacs from the GNU release tarball.
RUN curl -fsSL "https://ftpmirror.gnu.org/emacs/emacs-${EMACS_VERSION}.tar.xz" -o /tmp/emacs.tar.xz \
    && mkdir -p /tmp/emacs-src \
    && tar -xf /tmp/emacs.tar.xz -C /tmp/emacs-src --strip-components=1 \
    && cd /tmp/emacs-src \
    && ./configure --prefix=/usr/local \
         --with-native-compilation --with-tree-sitter --with-modules \
         --with-x-toolkit=gtk3 --with-rsvg --with-webp --with-xml2 --with-sqlite3 \
    && make -j"$(nproc)" \
    && make install \
    && cd / \
    && rm -rf /tmp/emacs-src /tmp/emacs.tar.xz

# The config invokes `fd` (Ubuntu installs the binary as `fdfind`).
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# difftastic (`difft`) for magit-difftastic; not packaged in Ubuntu.
RUN curl -fsSL "https://github.com/Wilfred/difftastic/releases/download/${DIFFT_VERSION}/difft-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/difft.tar.gz \
    && tar -xf /tmp/difft.tar.gz -C /usr/local/bin difft \
    && chmod +x /usr/local/bin/difft \
    && rm -f /tmp/difft.tar.gz

# Convenience launcher: load the config resiliently (skips the two packages
# that cannot build on Linux) via scripts/cloud-agent-bootstrap.el in the
# checkout that install links to ~/.emacs.d.
RUN printf '%s\n' \
      '#!/usr/bin/env bash' \
      'exec emacs -q --init-directory="$HOME/.emacs.d" \' \
      '  -l "$HOME/.emacs.d/scripts/cloud-agent-bootstrap.el" "$@"' \
      > /usr/local/bin/emacs-dev \
    && chmod +x /usr/local/bin/emacs-dev

# The Cloud Agent runs as the unprivileged `ubuntu` user (uid 1000), which the
# Ubuntu 24.04 base image already provides.
RUN id ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash -u 1000 ubuntu
USER ubuntu
