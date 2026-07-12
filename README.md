# .emacs.d

<p align="center">
  <strong>Dragonshock's personal Emacs configuration</strong><br/>
  modular · straight.el · use-package · Emacs 31
</p>

<p align="center">
  <a href="https://www.gnu.org/software/emacs/"><img src="https://img.shields.io/badge/Emacs-31-7F5AB6?style=flat-square&logo=gnuemacs&logoColor=white" alt="Emacs 31"></a>
  <a href="https://github.com/radian-software/straight.el"><img src="https://img.shields.io/badge/packages-straight.el-2ea44f?style=flat-square" alt="straight.el"></a>
  <a href="https://github.com/jwiegley/use-package"><img src="https://img.shields.io/badge/config-use--package-blue?style=flat-square" alt="use-package"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/license-personal-orange?style=flat-square" alt="License">
</p>

面向 **Emacs 31** 的模块化个人配置：启动优化、Vertico/Corfu 补全栈、Tree-sitter + Eglot、Ghostel 终端，以及 **gptel / Claude Code IDE / Codex IDE / Grok Build（agent-shell ACP）** 等 AI 工作流。主平台 **macOS**，Linux 为次要支持。

> 演进自 [roife/.emacs.d](https://github.com/roife/.emacs.d)，并持续按个人工作流定制。

---

## Highlights

| | |
|---|---|
| **启动** | `early-init` GC / 帧参数 / native-comp；`+init-files` 有序加载；耗时写入 `*Messages*` |
| **补全** | Vertico · Orderless · Marginalia · Consult · Embark · Corfu · Cape · Tempel |
| **编辑** | Eglot (+ booster) · Flymake · Tree-sitter · Citre · Puni · Dogears · vundo |
| **终端** | [Ghostel](https://github.com/roife/ghostel)（libghostty-vt）+ compile / comint / eshell |
| **VCS** | Magit · Forge · diff-hl · magit-difftastic · consult-gh |
| **AI** | gptel (DeepSeek) · gptel-magit · Claude Code IDE · Codex IDE · **Grok Build via agent-shell** |
| **写作** | Org (modern / appear / valign) · AUCTeX · markdown · Scheme / Geiser |

---

## Table of contents

- [Requirements](#requirements)
- [Install](#install)
- [Layout](#layout)
- [Startup flow](#startup-flow)
- [Keybindings](#keybindings)
- [AI: Grok Build in Emacs](#ai-grok-build-in-emacs)
- [Feature map](#feature-map)
- [Conventions](#conventions)
- [Customize](#customize)
- [Notes](#notes)

---

## Requirements

### Emacs

- **Emacs 31+**（当前开发机：`31.0.90` / emacs-plus）
- 推荐启用 native-comp

### Fonts

| Role | Family |
|------|--------|
| Default / fixed | **MonoLisaCode**（macOS 字号 14，其它 26） |
| Variable pitch | **MonoLisaText** |
| CJK (`han` / `cjk-misc`) | **LXGW WenKai Mono Screen** |
| Emoji (macOS) | **Apple Color Emoji**（rescale `0.79`） |
| Emoji (其它) | **Noto Color Emoji** |

### Theme

| Appearance | Theme variable | Theme name |
|------------|----------------|------------|
| Light | `+light-theme` | `doric-beach` |
| Dark | `+dark-theme` | `doric-valley` |

- 包：本地路径加载 [doric-themes](https://github.com/protesilaos/doric-themes)（见 `core/init-ui.el` 的 `:load-path`）
- macOS：跟随 `ns-system-appearance` 自动切换（`core/init-mac.el`）

### CLI tools

| Tool | Used for |
|------|----------|
| [`rg`](https://github.com/BurntSushi/ripgrep) | search / xref |
| [`fd`](https://github.com/sharkdp/fd) | file find |
| `aspell` | spell-check (flyspell) |
| [`difft`](https://github.com/Wilfred/difftastic) | Magit structural diff |
| `readability-cli` | cleaner EWW |
| [`grok`](https://docs.x.ai) | Grok Build CLI（`~/.grok/bin`，agent-shell ACP） |
| `claude` | Claude Code IDE（可选，`~/.local/bin`） |
| `zstd` *(optional)* | undo-fu-session compression |
| `gls` *(optional, macOS)* | GNU `ls` for dired |
| `tdlib` *(optional)* | telega |
| C toolchain *(first install)* | `emacs-reader` 的 `render-core.dylib` |

```bash
# macOS (Homebrew) example
brew install emacs-plus@31 ripgrep fd aspell difftastic zstd coreutils
# Grok Build CLI
curl -fsSL https://x.ai/cli/install.sh | bash
# optional
brew install tdlib
```

---

## Install

```bash
mv ~/.emacs.d ~/.emacs.d.bak 2>/dev/null
git clone <your-fork-url> ~/.emacs.d
```

1. 安装字体与 CLI 依赖  
2. 修改 `core/init-ui.el` 中 `doric-themes` 的 `:load-path`（或改回 straight 安装）  
3. 首次启动 Emacs：`straight.el` 自动 bootstrap 并拉取包  
4. AI 相关：在 `auth-source`（如 `~/.authinfo.gpg`）配置 DeepSeek API key；Grok 执行一次 `grok login`  

```text
machine api.deepseek.com login apikey password sk-...
```

---

## Layout

```text
.emacs.d/
├── early-init.el       # 启动前：GC、帧、package.el、闪屏抑制
├── init.el             # +init-files 注册表 + 按序 load-file
├── core/               # 全部业务模块（init-*.el）
│   ├── init-util.el    # add-hook! / defadvice! 等宏
│   ├── init-straight.el
│   ├── init-basic.el
│   ├── init-ui.el
│   ├── init-ghostel.el
│   ├── init-completion.el
│   ├── init-prog.el
│   ├── init-ai.el      # gptel / Claude / Codex / Grok agent-shell
│   └── ...
├── tempel-templates
└── scripts/            # 辅助脚本（如 telega tdlib）
```

模块顺序由 `init.el` 的 **`+init-files`** 唯一决定（后加载可依赖先加载）。

| Module | Responsibility |
|--------|----------------|
| `init-util` | 自定义宏 |
| `init-straight` | straight + use-package 默认值 |
| `init-basic` | 文件/备份/滚动/TRAMP/GCMH/history |
| `init-ui` | 字体、主题、ligature、scrollview |
| `init-xterm` | TTY / Kitty graphics |
| `init-ghostel` | Ghostel 终端 |
| `init-mac` | macOS（系统外观、词典）— 仅 Darwin 加载 |
| `init-completion` | Vertico / Corfu / Consult / Embark … |
| `init-tools` | project、undo、isearch、avy … |
| `init-keybinding` | Super 键、中文标点翻译 |
| `init-highlight` | 括号、TODO、pulse … |
| `init-edit` | 编辑增强、electric-pair |
| `init-spell` | ispell / flyspell |
| `init-window` | ace-window、popper、zoom |
| `init-dired` | dired 全家桶 |
| `init-eshell` | Eshell 增强 + `C-\`` toggle |
| `init-prog` | LSP / treesit / 语言模式 |
| `init-scheme` | Geiser |
| `init-writing` | Markdown / AUCTeX |
| `init-org` | Org |
| `init-vcs` | Magit / Forge / diff-hl |
| `init-browser` | browse-url / eww |
| `init-ibuffer` | ibuffer |
| `init-dict` | google-this / google-translate |
| `init-modeline` | 自定义 mode-line |
| `init-tabbar` | tab-bar |
| `init-ai` | AI 全家桶 |
| `init-chat` | telega |
| `init-pdf` | emacs-reader |
| `init-elfeed` | RSS |
| `init-test` | 个人实验 / JDTLS · rust-analyzer 辅助（**不是**单元测试） |

注释掉的模块：`init-ime`、`init-modal`。

---

## Startup flow

```text
early-init.el  →  init.el  →  core/init-util  →  core/init-straight  →  rest of +init-files
                                                                      →  window-setup timings
```

1. **`early-init.el`** — 提高 GC 阈值、native-comp JIT、关闭 package.el 启动初始化、`default-frame-alist`（160×60、tab-bar、无 menu/tool/scroll bar）、抑制启动闪烁  
2. **`init.el`** — 按 `+init-files` `load-file`  
3. **交互会话** — `use-package-always-defer` 为 `t`；daemon 下 `use-package-always-demand` 为 `t`  

启动后在 `*Messages*`：

```text
window-setup: x.xxxs, after-init: y.yyys
```

---

## Keybindings

### Super (macOS ⌘)

| Key | Command |
|-----|---------|
| `s-s` | save-buffer |
| `s-x` / `s-c` / `s-v` | kill / copy / yank |
| `s-z` / `s-Z` | undo / undo-redo |
| `s-a` | mark-whole-buffer |
| `s-w` / `s-t` | tab-close / tab-new |
| `s-o` | other-window |
| `s-,` | xref-go-back |
| `s-.` | embark-dwim |

### Search & navigation

| Key | Command |
|-----|---------|
| `M-s l` | consult-line |
| `M-s r` | consult-ripgrep |
| `M-s d` | consult-fd |
| `C-c i` / `C-c I` | consult-imenu / multi |
| `C-.` | embark-act |
| `M-.` | embark-dwim |

### `C-,` ad-hoc prefix

| Key | Command |
|-----|---------|
| `C-, .` / `C-, ,` / `C-, l` | avy-goto-char / char-2 / line |
| `C-, j` / `C-, c` | link-hint open / copy |
| `C-, g l` / `c` / `h` | git-link / commit / homepage |
| `C-, o` / `C-, e` | browse-url-at-point / browse-url-emacs |
| `C-, w` | google-this |

### Project · Magit · Terminal · AI

| Key | Command |
|-----|---------|
| `C-x p m` | magit-status |
| `C-x p t` / `T` | ghostel-project / list buffers |
| `C-x g` | magit |
| `C-x m` | ghostel |
| `C-\`` | `+eshell-toggle`（底部 Eshell 弹窗） |
| `C-c C-g` | **Grok Build**（agent-shell） |
| `C-c C-'` | claude-code-ide-menu |
| `C-c r t` | gptel rewrite → 简体中文 |
| Embark region `T` | 同上 |
| Embark general `?` | gptel-quick |

### Grok buffer（agent-shell-mode）

| Key | Command |
|-----|---------|
| `C-c C-c` | **中断当前 turn**（会确认；不是关窗口） |
| `C-c C-q` | bury 窗口（进程保留） |
| `C-u C-c C-q` | 杀掉 buffer / 会话进程 |
| `RET` | 发送提示 |
| `/…` | Grok agent 侧 slash 命令（若会话已宣告 `availableCommands`） |
| `@file` | 文件补全（`agent-shell-file-completion-enabled`） |

### Programming

| Key | Command |
|-----|---------|
| `C-c r` | quickrun |
| `C-c c j/k/p/a/u` | citre jump / back / peek / ace / update |
| `C-c f ]` / `[` / `b` | flymake next / prev / buffer |
| `M-RET` *(eglot)* | code actions |
| `M-/` / `M-?` | typeDefinition / references |

中文标点在 `C-` / `M-` / `s-` / `H-` 前缀下经 `key-translation-map` 映射为英文标点。

---

## AI: Grok Build in Emacs

配置见 `core/init-ai.el`。

### 架构

- **不走** Ghostel / 终端 TUI  
- **走** [agent-shell](https://github.com/xenodium/agent-shell) + [ACP](https://agentclientprotocol.com/)：`grok agent -m grok-4.5 stdio`  
- 窗口：右侧普通分窗（`agent-shell-display-action`），**不**进 popper 弹窗列表（避免与 `C-g` / 底部 popup 冲突）  
- 首选 agent：`agent-shell-preferred-agent-config` → `grok-build`

### 启动

| 操作 | 效果 |
|------|------|
| `C-c C-g` / `M-x +agent-shell-start-grok` | 新建 Grok shell buffer（同项目可复用显示） |
| `M-x agent-shell` | 因 preferred config，直接走 Grok |

首次需：`grok` 在 `PATH`（配置会把 `~/.grok/bin` 写入 `exec-path`），并已 `grok login`。

### 如何 resume 之前的会话

Grok 会话落盘在 `~/.grok/sessions/<编码后的 cwd>/<session-id>/`。  
**agent-shell 与 Grok TUI 共用同一套会话存储**，但 **入口不同**：

#### 方式 A — Emacs：`agent-shell-resume-session`（推荐按 ID）

```text
M-x agent-shell-resume-session RET
```

提示输入 **Session ID**（UUID，例如 `019f47d9-52a2-71e0-b5b3-3df9e6b8d776`），然后选 agent（本配置默认 Grok）。

程序化等价：

```elisp
(agent-shell-start
 :config (agent-shell-xai-make-grok-config)
 :session-id "019f47d9-52a2-71e0-b5b3-3df9e6b8d776")
```

#### 方式 B — Emacs：启动时选会话（agent 支持 list/load 时）

全局默认（agent-shell 上游）：

```elisp
agent-shell-session-strategy  ; 'prompt | 'latest | 'new
```

- **`prompt`**（默认）：agent 若宣告 `session/list` + `session/load`（或 `session/resume`），启动时会弹出会话列表  
- **`latest`**：直接恢复最近会话  
- **`new`**：始终新建  

恢复时展示多少历史由：

```elisp
agent-shell-session-restore-verbosity  ; 'minimal | 'last | 'first-last | 'full
```

控制（`minimal` 最快，只显示标题；`full` 重放全文）。

#### 方式 C — 终端 / 命令行（不经过 agent-shell）

```bash
# 当前目录最近一次
grok --resume
# 或
grok -c

# 指定 ID
grok --resume 019f47d9-52a2-71e0-b5b3-3df9e6b8d776

# 列出 / 搜索
grok sessions list
grok sessions search "过时"
```

#### 方式 D — Grok **TUI** 内

```text
/resume
```

或快捷键 **`Ctrl+S`** 打开 session picker。  
这是 **Grok 前端 pager** 功能；agent-shell 是 ACP 客户端，**没有同名的 `/resume` UI 命令**，除非 Grok 通过 `availableCommands` 把某个 slash 暴露给 agent 侧（以 buffer 里 “Available /commands” 为准）。

#### 怎么查 Session ID

```bash
# 本仓库目录下的会话
grok sessions list

# 或直接看磁盘
ls ~/.grok/sessions/%2FUsers%2Fdragon%2F.emacs.d/
# 每个子目录名就是 session-id；summary.json 里有 title / updated_at
```

在已打开的 agent-shell buffer 中，会话建立后也可在 header / mode-line 相关状态里看到 session 信息（视 agent-shell 版本与 capabilities）。

### 注意

| 现象 | 原因 |
|------|------|
| 长任务突然 “Cancelled” | `C-c C-c` 中断了 turn（会确认） |
| 突然 “Rate limited / free usage exhausted” | Grok 免费额度用尽（会话日志里可见 `stop_reason=rate_limit`） |
| 想关窗口却按了 `C-c C-c` | 应用 **`C-c C-q`** bury，或 `C-u C-c C-q` 杀进程 |

---

## Feature map

### Completion stack

```text
Vertico ── Orderless ── Marginalia
   │
Consult / Embark ── actions & search
   │
Corfu + Cape + Tempel ── in-buffer completion / snippets
```

### Programming

- **LSP**: 内置 Eglot + `eglot-booster`（`io-only`）+ `consult-eglot`
- **Diagnostics**: Flymake（行尾短提示）
- **Tree-sitter**: `treesit-enabled-modes t`，grammar `always` 自动安装，font-lock level 4
- **Rust**: `rust-mode-treesitter-derive`、cargo minor mode
- **Jump**: Citre + dumb-jump fallback + xref（ripgrep）
- **自动 Eglot**：`c` / `c++` / `rust` / `python` / `java`（含 ts 模式）

### Ghostel

- 绑定 `C-x m`；项目终端 `C-x p t`
- 子模式：`ghostel-compile` / `ghostel-comint` / `ghostel-eshell`
- TRAMP 远程 shell、OSC 8 超链、Kitty 图形
- 输入模式：semi-char / char / emacs / copy / line

### AI（全貌）

| Package | Role |
|---------|------|
| **gptel** | DeepSeek chat（thinking 默认开）、org 会话；`deepseek-v4-flash` |
| **gptel-quick** | Embark `?` 一句话解释 |
| **gptel-magit** | Conventional Commits 风格提交说明 |
| **claude-code-ide** | Claude Code CLI + MCP + Ghostel 右侧栏 |
| **codex-ide** | Codex IDE 集成 |
| **agent-shell + Grok** | Grok Build ACP（`C-c C-g`） |

### Org & writing

- `org-modern` + `org-modern-indent` + `org-appear` + `valign`
- AUCTeX / cdlatex / reftex；markdown

### Windows & UI

- **Popper** 弹窗（help / compilation / eshell-popup 等）；**agent-shell 不在列表中**
- Zoom 主窗、ace-window 编号
- 自定义 modeline + breadcrumb header-line
- tab-bar、window-divider、ligature、scrollview fringe

---

## Conventions

| Pattern | Meaning |
|---------|---------|
| `+name` | 本配置自定义函数 / 变量 |
| `*-a` / `*-h` | `defadvice!`：around / hook |
| `lexical-binding: t` | 每个文件首行 |
| `:straight t` | 第三方包 |
| `:straight nil` / built-in | 内置或父包附带扩展 |
| `custom.el` | Customize 落盘（gitignore） |
| `autosaves/` · `backups/` | 自动保存与备份（gitignore） |

核心宏（`core/init-util.el`，风格接近 Doom）：

- `add-hook!` — 多 hook / 多函数，`:local` / `:append` / `:call-immediately` / `:unless-daemonp-call-immediately`
- `defadvice!` — 定义并挂载 advice
- `+advice-pp-to-prin1!` — 缩小 saveplace / recentf 等缓存体积

---

## Customize

### 新增包

在对应 `core/init-*.el` 增加 `use-package`；若需新模块：

1. 新建 `core/init-foo.el`  
2. 把 `'init-foo` 加入 `init.el` 的 `+init-files`（**顺序敏感**；勿放在 `init-straight` 之前）

### 常用旋钮

| Want | Where |
|------|--------|
| 主题明暗 | `core/init-ui.el` → `+light-theme` / `+dark-theme` |
| 字号 | `core/init-ui.el` → `+font-size` |
| AI 模型 / Grok 命令 | `core/init-ai.el` → `agent-shell-xai-grok-acp-command`、`gptel-*` |
| 会话恢复策略 | `agent-shell-session-strategy` / `agent-shell-session-restore-verbosity` |
| 自动 Eglot 语言 | `core/init-prog.el` → `+eglot-auto-start-modes` |
| 模块开关 | `init.el` → `+init-files`（注释即可禁用） |

### 热重载单个模块

```text
M-x load-file RET core/init-FOO.el RET
```

注意：`use-package-always-defer` 为 `t` 时，`:config` 要等真正加载该包后才会再跑。

---

## Notes

- **`init-test.el` 不是测试套件**，会正常加载。  
- **无自动化测试**；验证：启动 Emacs，看 `*Messages*` 耗时，手动点功能。  
- 本地绝对路径（`doric-themes` load-path 等）clone 后需按机器改写。  
- README 与代码不一致时以 **`core/*.el` + `init.el` 的 `+init-files`** 为准。  
- 上游参考：[roife/.emacs.d](https://github.com/roife/.emacs.d)

---

## License

个人配置，按需自取。第三方包遵循各自许可证。  
若你基于本配置衍生，欢迎 star / fork，并保留对上游 roife 配置的致谢。

---

<p align="center">
  <sub>Built for thinking with code · Emacs 31</sub>
</p>
