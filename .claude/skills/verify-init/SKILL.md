---
name: verify-init
description: Run the full Emacs startup smoke test for this config — loads early-init.el + init.el in a clean batch Emacs, reports startup timings and any uncaught errors. Use after editing any core/*.el, init.el, or early-init.el, and whenever asked to "verify", "check startup", or "make sure init still works".
---

这个仓库没有测试框架和 CI，启动冒烟测试就是唯一的验收手段。

## 步骤

1. 跑完整启动路径。**`emacs` 不在 PATH 上**，必须用完整路径：

   ```bash
   EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
   "$EMACS" -Q --debug-init \
     -l "$HOME/.emacs.d/early-init.el" \
     -l "$HOME/.emacs.d/init.el" \
     --eval '(kill-emacs 0)' 2>&1; echo "exit=$?"
   ```

   给它 120s 以上的超时——冷启动可能要现装包或原生编译。

2. 判读输出：

   - **通过**：出现 `window-setup: <x>s, after-init: <y>s`，退出码 0，没有 backtrace。
     （注意：`-Q` 批处理下 `window-setup-hook` 可能不触发，此时以「退出码 0 且无 error backtrace」为准，并在报告里说明。）
   - **失败**：任何 `Symbol's function definition is void`、`Wrong type argument`、`Cannot open load file`、`Debugger entered--Lisp error` 或非 0 退出码。
   - **噪音**（不算失败，但值得提一句）：straight 的 `Cloning ...`、native-comp 警告、`Package cl-lib is deprecated` 之类。

3. 如果失败，定位到具体模块：按 `init.el` 里 `+init-files` 的顺序看最后一个成功加载的模块，然后对可疑文件单独跑

   ```bash
   "$EMACS" -Q --batch \
     -l "$HOME/.emacs.d/core/init-util.el" \
     -l "$HOME/.emacs.d/core/init-straight.el" \
     -f batch-byte-compile "$HOME/.emacs.d/core/init-FOO.el"
   ```

   不预加载 `init-util` / `init-straight` 的话，输出会是满屏 `Unrecognized keyword: :straight`，毫无用处。即便预加载了，`free variable` / `Cannot load` / `defined multiple times` 仍是延迟加载造成的假阳性，忽略即可——以完整启动路径的结论为准。`.claude/hooks/elisp-check.sh` 里有同样的过滤逻辑可以参考。

4. 报告时给出：结论（通过/失败）、`window-setup` 与 `after-init` 耗时（如果有）、失败的具体文件和 error 原文。启动耗时明显变慢（比如超过 1.5s）时提醒用户，因为这个配置的 early-init 就是为启动速度调的。

不要为了让测试通过而改配置——先报告，等用户决定。
