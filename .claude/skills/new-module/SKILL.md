---
name: new-module
description: Scaffold a new core/init-<name>.el module in this Emacs config and register it in the +init-files list in init.el at the correct dependency position. Use when adding a new feature area or a group of packages that doesn't belong in an existing module.
---

新增模块：`$ARGUMENTS`（模块名，不带 `init-` 前缀和 `.el` 后缀；没给就问用户）。

## 步骤

1. **确认它真的需要新模块。** 如果只是加一两个包，且已有模块的主题吻合（补全 → `init-completion.el`，编程 → `init-prog.el`，编辑 → `init-edit.el`，AI → `init-ai.el`），直接加进去，不要新建文件。先读一遍候选模块再决定。

2. **建 `core/init-<name>.el`**，用房规骨架：

   ```elisp
   ;;; -*- lexical-binding: t -*-

   ;; [package-name] 一句话说明
   (use-package package-name
     :straight t
     :commands (some-command)
     :bind (("C-c x" . some-command))
     :init
     (setq package-name-option t)
     :config
     ...)
   ```

   规矩（详见 CLAUDE.md）：
   - 文件头固定 `;;; -*- lexical-binding: t -*-`，**不要**加 `(provide ...)` 或 `;;; ... ends here` —— 模块是被 `load-file` 的，不是 `require`。（例外：`init-org` / `init-scheme` / `init-ghostel` / `init-agent-shell` 有完整 header，那是历史遗留，新文件不用跟。）
   - 每个 `use-package` 块前一行 `;; [package-name] 说明`，块之间空两行。
   - `use-package-always-defer` 默认为 `t`，所以**必须**给 `:commands` / `:bind` / `:hook` 之一作为触发点，否则包永远不会加载。
   - 自定义函数/变量/face 一律 `+` 前缀；hook 函数 `-h` 结尾，advice `-a` 结尾。
   - 用 `add-hook!` / `defadvice!`（来自 `init-util.el`），少写裸 `add-hook` / `advice-add`。
   - 依赖外部二进制或原生模块的，用 `condition-case` 包住，缺失时不能中断 init（参考 `core/init-edit.el` 的 `+jinx-mode-maybe`）。
   - macOS 专用逻辑放 `init-mac.el`，或用 `(eq system-type 'darwin)` 守卫。

3. **登记进 `init.el` 的 `+init-files`**，插在依赖之后。参考现有顺序：`util → straight → basic → ui → xterm → ghostel → [mac] → completion → tools → keybinding → highlight → edit → window → dired → shell → prog → scheme → writing → org → vcs → browser → ibuffer → dict → modeline → ai → agent-shell → social → elfeed → test`。功能类模块放在同类邻居旁边；试验性的放靠后（`init-test` 之前）。**不要**重排已有条目。

4. **验证**：跑 `/verify-init`，确认启动无 error。（`emacs` 不在 PATH 上，直接跑要用 `/Applications/Emacs.app/Contents/MacOS/Emacs`。）

5. 告诉用户：新建了哪个文件、插在 `+init-files` 的什么位置、以及需要装的外部依赖（brew 包、字体、语言 server 之类）。
