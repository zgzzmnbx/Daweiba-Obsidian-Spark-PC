# 项目 AGENTS.md

## 项目边界

- 本项目只交付 AutoHotkey v2 `.ahk` 源码，不生成 EXE。
- GitHub 备份仓库为 `https://github.com/zgzzmnbx/Daweiba-Obsidian-Spark-PC`，默认分支为 `main`。
- AutoHotkey 官方安装包只允许作为 GitHub Release 附件发布，不提交进源码分支。
- 默认 Vault 为 `C:\OBS\Damon`，闪念目标为 `C:\OBS\Damon\【MOC】闪念-随手记.md`。
- 普通闪念和待办只允许写入配置中的唯一锚点正下方；默认锚点为 `<!-- DABAWEI_FLASHNOTE_INBOX -->`。
- 新建笔记必须位于配置的 Vault 之内，不覆盖同名文件。

## 安全写入

- 正式写入前先在 `Codex-Temp/` 夹具中测试。
- 目标锚点必须恰好出现一次；否则停止写入。
- 保留 UTF-8 BOM 状态，使用同目录临时文件和 `MoveFileExW` 原子替换。
- 替换前重读目标并检查并发变化；不得静默覆盖 Obsidian、同步盘或手机端新内容。
- 对 Windows 文件占用错误 5、32、33 进行有界重试；仍失败则提示用户重试。

## 闪念 Markdown 格式

- 不得把多行剪贴板统一压成 ` / `；这会丢失网页段落结构。
- 普通闪念和待办的续行使用两个空格缩进，单换行使用 Markdown 行尾两空格，原空行保留为一个段落间隔。
- 修改段落格式时，必须同时回归普通闪念、Obsidian Tasks 待办、Dataview 字段和块 ID 归属。
- 内容格式仅允许 `smart_markdown`、`code_block`、`plain_text`；当前按用户要求默认 `code_block`。
- 网页加粗必须以 CF_HTML 中的 `<strong>/<b>` 或行内 `font-weight:bold/600–900` 为证据，不从纯文本猜测格式。
- 代码块语言标记固定为完整的 `markdown`，不使用 `md`。
- 围栏代码块不渲染加粗；如正文已包含反引号围栏，外层围栏必须自动加长。
- `code_block` 模式下，普通闪念的标签、围栏、正文、Dataview 字段和块 ID 必须全部顶格，避免 Obsidian 软换行不继承列表缩进；待办仍嵌套在 `- [ ]` 下，保持 Tasks 语义。
- 网页普通闪念必须根据可靠来源网址提取域名，增加“来自`域名`网页的剪藏。”；没有可靠网址时不得猜测域名。
- 三组快捷键各自可关闭；默认仅启用普通闪念和新建笔记。只注册启用项，只校验启用项的非空与重复冲突。
- 新建笔记默认在闪念目标笔记锚点下回写 Vault 相对 Wikilink；独立笔记创建成功但链接写入失败时必须明确报告部分成功，不删除已创建笔记。

## 中文配置

- `config.ini` 使用 `ConfigStore.ahk` 以 UTF-8 读写。
- 不得改回 `IniRead` / `IniWrite`；Windows INI API 会把无 BOM UTF-8 中文路径读乱。
- 不在项目代码中写死 AutoHotkey 解释器安装路径；运行时使用 `A_AhkPath`。
- Vault、闪念目标笔记、新建笔记目录和插入锚点在设置主界面中必须保持只读；前三者仅能通过“选择”更新，锚点仅能通过“修改”更新。
- 实际写入必须使用 `[Write] Anchor` 配置值，不得绕回固定常量；保存配置前验证锚点非空且在目标笔记中恰好出现一次。

## 网页来源与隐私

- 来源优先级固定为 `SourceURL → UI Automation → 地址栏复制兜底`。
- UI Automation 必须放在 `BrowserUrlWorker.ahk` 独立进程中并设置有界超时，不让浏览器兼容问题卡住保存。
- 地址栏兜底前保存 `ClipboardAll`，完成后必须恢复；恢复失败时取消保存并报错。
- 日志不得记录剪贴板正文或完整来源网址，只记录获取方式和成功/失败。

## 验证基线

- 回归测试：`tests/CoreTests.ahk`。
- UI 冒烟：主脚本参数 `--ui-smoke-check` 和 `--new-note-smoke-check`。
- 浏览器诊断：`tests/BrowserSourceProbe.ahk`，输出不得包含完整网址。
- 真实 Vault 验收前必须备份并记录 SHA-256；验收块必须清除并复核原文件哈希。
