# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

个人 Emacs 配置（fork 自 `roife/.emacs.d`）。`early-init.el` 只做启动优化；`init.el` 是模块清单，按固定顺序 `load-file` 加载 `core/*.el`。包管理用 **straight.el + use-package**。

## 加载模型

- `init.el` 里的 `+init-files` 是**唯一**模块清单，用 `load-file` 顺序加载 `core/<name>.el`——不是 `require`，所以绝大多数模块**没有** `(provide ...)`，也不需要加。
- 依赖链固定：`init-util`（提供 `add-hook!` / `defadvice!` 宏）→ `init-straight` → `init-basic` → 其余。**不要重排前三项。**
- 平台条件项写成 `(when (eq system-type 'darwin) 'init-mac)`；`nil` 会被跳过。
- `init-ime`、`init-modal` 是**故意注释掉**的，除非用户明确要求，不要启用。
- 新模块 = 新建 `core/init-foo.el` + 在 `+init-files` 里按依赖位置插入一行。

## 包管理

- `package.el` 在 `early-init.el` 里已禁用（`package-enable-at-startup nil`）。**不要启用它，也不要和 straight 混装**；`elpa/` 只剩历史残留。
- 新包一律 `use-package` + `:straight t` 或 recipe（`(:host github :repo "user/pkg")`）。
- `use-package-always-defer` 在非 daemon 下为 `t`：**GUI 会话里每个 `use-package` 默认延迟加载**，所以 `:commands` / `:bind` / `:hook` 是必需的触发点，漏写会导致包永远不加载。`:config` 里的东西只有包真正加载后才生效，纯变量设置放 `:init`。
- 包变更后在 Emacs 内跑 `M-x straight-freeze-versions`，确认 `straight/versions` 有 diff 再提交（`straight/build`、`straight/repos` 不提交）。

## 代码风格

- 文件头一律 `;;; -*- lexical-binding: t -*-`。
- 每个 `use-package` 块前一行 `;; [package-name] 一句话说明`，块之间空两行。
- 用户自定义符号一律 `+` 前缀：`+eshell-toggle`、`+gc-cons-threshold`、`+mode-line-*`。hook 函数以 `-h` 结尾，advice 以 `-a` 结尾，宏以 `!` 结尾。
- 优先用 `init-util.el` 的 `add-hook!` / `defadvice!`，少写裸 `add-hook` / `advice-add`（early-init 级除外，那里 `init-util` 还没加载）。
- 空格缩进，`indent-tabs-mode nil`，`tab-width 4`。没有 elisp formatter——elisp 靠 Emacs 内建 `indent-region`；`apheleia` 只管其他语言。
- 任何依赖原生模块 / 外部二进制的东西（jinx、telega/TDLib、tree-sitter、ghostel）都要用 `condition-case` 包住，缺失时不能中断 init。参考 `core/init-edit.el` 里的 `+jinx-mode-maybe`。

## 两个必须记住的坑

1. **带 `:set` 的 defcustom 必须用 `setopt`，而且要先 `require` 它所在的库**。`setq` 会绕过 setter 静默失效；但光换 `setopt` 在这份配置里也不够——`early-init.el` 给 `setopt--set` 加了 advice 绑定 `custom-load-recursion`，使 `custom-load-symbol` 变成空操作，所以库没加载时 `setopt` 会退化成 `set-default`，同样静默失效。`treesit-enabled-modes` 就是典型（它的 setter 才负责把 26 条映射装进 `major-mode-remap-alist`）。正确写法见 `core/init-prog.el` 的 treesit 块。改任何变量前先确认：

   ```bash
   "$EMACS" -Q --batch --eval '(progn (require (quote LIB)) (princ (format "%s" (get (quote VAR) (quote custom-set)))))'
   ```

2. **minor mode 不能用 `setq` 打开**。`(setq foo-mode t)` 只是改了状态变量，模式机制不会启动——要用 `:hook` 或 `(foo-mode 1)`。这个配置里 `minibuffer-electric-default-mode`、`vc-auto-revert-mode`、`TeX-source-correlate-mode` 都踩过。

## 验证

**`emacs` 不在 PATH 上**——本机只有 `/Applications/Emacs.app/Contents/MacOS/Emacs`（当前 31.0.91）。任何命令行调用都要用完整路径：

```bash
EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
"$EMACS" -Q --debug-init -l ~/.emacs.d/early-init.el -l ~/.emacs.d/init.el --eval '(kill-emacs 0)'
```

期望：退出码 0，无未捕获 error（交互启动时 `*Messages*` 会有 `window-setup: …s, after-init: …s`）。这条封装在 `/verify-init` skill 里。

单文件抽查必须预加载宏和 `use-package` 的 `:straight` 关键字，否则输出全是假阳性：

```bash
"$EMACS" -Q --batch -l core/init-util.el -l core/init-straight.el -f batch-byte-compile core/init-FOO.el
```

即便如此，「free variable」「Cannot load」「defined multiple times」仍是延迟加载导致的噪音，可忽略；真正要看的是 arity、obsolete、语法类警告。`.claude/hooks/elisp-check.sh` 已经做了这层过滤，编辑 `.el` 后自动跑。

没有 Makefile / CI / 测试框架，以上就是全部检查手段。

## 兼容性

- 需要同时能在 **Emacs 30 和 31** 上跑（`eln-cache/` 里有 30.2 / 31.0.9x 三个 ABI）。用到 31 才有的东西必须加版本守卫，参考 `core/init-vcs.el` 里的 `(>= emacs-major-version 31)`。
- macOS 专用代码放 `core/init-mac.el`，或用 `(eq system-type 'darwin)` 守卫；Homebrew 路径按 `/opt/homebrew` 与 `/usr/local` 两种都处理。

## 禁区

- **不要**动 `early-init.el` 的启动时序技巧（GC 阈值、`file-name-handler-alist` 置空与恢复、silence advice、`package-enable-at-startup`），除非任务本身就是调启动性能。
- **不要**在 `init.el` / `early-init.el` 里写业务配置——`init.el` 只是清单。
- **不要**提交：`custom.el`、`private.el`、`secrets.el`、`local.el`、authinfo、`.env`、密钥、`straight/build`、`straight/repos`、`eln-cache`、`elpa/`、`backups/`、`autosaves/`。
- **不要**把代理 `url-proxy-services` 硬编码提交。
- **不要**碰用户隐私数据目录：`elfeed/`、`rime/`、history 类文件。

## 提交范围

一次改动 = 相关 `core/init-*.el` ± `init.el` 一行登记 ± `straight/versions`。不要顺手大扫除。commit message 中英文皆可，与现有 log 保持一致。

## 其他 agent 文档

本地还有几份（已 gitignore，不随仓库分发）：`AGENTS.md`（本文件的前身）、`CONTEXT.md`（ACP / agent-shell / Grok 术语表）、`docs/agents/`（issue tracker、triage labels、domain docs）。涉及 `core/init-agent-shell.el` 时先读 `CONTEXT.md`。
