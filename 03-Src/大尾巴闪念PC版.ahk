#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

#Include "lib\FlashNoteCore.ahk"
#Include "lib\ClipboardFormatter.ahk"
#Include "lib\ConfigStore.ahk"
#Include "lib\BrowserSource.ahk"
#Include "lib\ImageClipboard.ahk"

class FlashNoteApp {
    static Version := "0.5.0"

    __New() {
        SplitPath(A_ScriptDir, , &projectRoot)
        this.ProjectRoot := projectRoot
        this.ConfigPath := projectRoot "\config.ini"
        this.LogDir := projectRoot "\logs"
        this.LogPath := this.LogDir "\flashnote-pc.log"
        this.StartupShortcut := A_Startup "\大尾巴闪念PC版.lnk"
        this.SettingsGui := ""
        this.NewNoteGui := ""
        this.UsageGui := ""
        this.PendingNewNoteImage := ""
        this.ActiveHotkeys := []
        this.HotkeysPaused := false
        this.LastCreatedNote := ""
        this.Config := this.LoadConfig()
    }

    Start() {
        A_IconTip := "大尾巴闪念 PC 版"
        this.ConfigureTray()
        this.BuildSettingsGui()
        errorMessage := this.ApplyHotkeys(this.Config)
        if (errorMessage != "") {
            this.UpdateStatus("快捷键未启用，请检查设置", true)
            MsgBox(errorMessage, "快捷键启用失败", "Iconx")
        }
        this.ShowSettings()
        this.Log("app_start", "ok", "", "none")
    }

    DefaultConfig() {
        return {
            Vault: "C:\OBS\Damon",
            FlashNote: "C:\OBS\Damon\【MOC】闪念-随手记.md",
            NewNoteFolder: "C:\OBS\Damon\01-看板-日记-杂项",
            Anchor: FlashNoteCore.DefaultAnchor,
            NormalHotkey: "^!s",
            TodoHotkey: "^!t",
            NewNoteHotkey: "^!n",
            NormalEnabled: 1,
            TodoEnabled: 0,
            NewNoteEnabled: 1,
            LinkNewNoteInFlash: 1,
            SourceUrlEnabled: 1,
            BrowserFallback: 1,
            AddressBarCopyFallback: 1,
            ContentFormat: ClipboardFormatter.CodeBlock,
            StartWithWindows: 0
        }
    }

    LoadConfig() {
        defaults := this.DefaultConfig()
        if !FileExist(this.ConfigPath) {
            this.WriteConfig(defaults)
            return defaults
        }
        values := ConfigStore.Read(this.ConfigPath)
        return {
            Vault: ConfigStore.Get(values, "Paths", "Vault", defaults.Vault),
            FlashNote: ConfigStore.Get(values, "Paths", "FlashNote", defaults.FlashNote),
            NewNoteFolder: ConfigStore.Get(values, "Paths", "NewNoteFolder", defaults.NewNoteFolder),
            Anchor: ConfigStore.Get(values, "Write", "Anchor", defaults.Anchor),
            NormalHotkey: ConfigStore.Get(values, "Hotkeys", "Normal", defaults.NormalHotkey),
            TodoHotkey: ConfigStore.Get(values, "Hotkeys", "Todo", defaults.TodoHotkey),
            NewNoteHotkey: ConfigStore.Get(values, "Hotkeys", "NewNote", defaults.NewNoteHotkey),
            NormalEnabled: Integer(ConfigStore.Get(values, "Hotkeys", "NormalEnabled", defaults.NormalEnabled)),
            TodoEnabled: Integer(ConfigStore.Get(values, "Hotkeys", "TodoEnabled", defaults.TodoEnabled)),
            NewNoteEnabled: Integer(ConfigStore.Get(values, "Hotkeys", "NewNoteEnabled", defaults.NewNoteEnabled)),
            LinkNewNoteInFlash: Integer(ConfigStore.Get(values, "NewNote", "LinkInFlashNote", defaults.LinkNewNoteInFlash)),
            SourceUrlEnabled: Integer(ConfigStore.Get(values, "SourceUrl", "Enabled", defaults.SourceUrlEnabled)),
            BrowserFallback: Integer(ConfigStore.Get(values, "SourceUrl", "BrowserFallback", defaults.BrowserFallback)),
            AddressBarCopyFallback: Integer(ConfigStore.Get(values, "SourceUrl", "AddressBarCopyFallback", defaults.AddressBarCopyFallback)),
            ContentFormat: ConfigStore.Get(values, "Content", "Format", defaults.ContentFormat),
            StartWithWindows: Integer(ConfigStore.Get(values, "Startup", "StartWithWindows", defaults.StartWithWindows))
        }
    }

    WriteConfig(config) {
        ConfigStore.Write(this.ConfigPath, config)
    }

    ConfigureTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("打开设置", (*) => this.ShowSettings())
        A_TrayMenu.Add("使用说明", (*) => this.ShowUsageGuide())
        A_TrayMenu.Add("暂停/恢复快捷键", (*) => this.TogglePause())
        A_TrayMenu.Add()
        A_TrayMenu.Add("打开闪念目标笔记", (*) => this.OpenFlashNote())
        A_TrayMenu.Add("打开新建笔记目录", (*) => this.OpenNewNoteFolder())
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", (*) => this.ExitApplication())
        A_TrayMenu.Default := "打开设置"
    }

    BuildSettingsGui() {
        settingsGui := Gui("+MinSize660x650", "大尾巴闪念 PC 版 v" FlashNoteApp.Version)
        settingsGui.SetFont("s10", "Microsoft YaHei UI")
        settingsGui.MarginX := 18
        settingsGui.MarginY := 16

        settingsGui.Add("Text", "xm w610 c1F4E79", "复制内容后，用三个全局快捷键保存到 Obsidian")
        this.StatusText := settingsGui.Add("Text", "xm y+8 w610", "状态：正在初始化")

        settingsGui.Add("GroupBox", "xm y+14 w620 h182", "写入位置")
        settingsGui.Add("Text", "xm+14 yp+28 w125", "闪念目标笔记")
        this.FlashPathEdit := settingsGui.Add("Edit", "x+0 yp-3 w370 ReadOnly", this.Config.FlashNote)
        settingsGui.Add("Button", "x+8 yp-1 w75", "选择").OnEvent("Click", (*) => this.SelectFlashNote())
        settingsGui.Add("Text", "xm+14 y+18 w125", "新建笔记目录")
        this.NewFolderEdit := settingsGui.Add("Edit", "x+0 yp-3 w370 ReadOnly", this.Config.NewNoteFolder)
        settingsGui.Add("Button", "x+8 yp-1 w75", "选择").OnEvent("Click", (*) => this.SelectNewNoteFolder())
        settingsGui.Add("Text", "xm+14 y+18 w125", "Vault 根目录")
        this.VaultEdit := settingsGui.Add("Edit", "x+0 yp-3 w370 ReadOnly", this.Config.Vault)
        settingsGui.Add("Button", "x+8 yp-1 w75", "选择").OnEvent("Click", (*) => this.SelectVault())
        settingsGui.Add("Text", "xm+14 y+18 w125", "插入锚点")
        this.AnchorEdit := settingsGui.Add("Edit", "x+0 yp-3 w370 ReadOnly", this.Config.Anchor)
        settingsGui.Add("Button", "x+8 yp-1 w75", "修改").OnEvent("Click", (*) => this.ModifyAnchor())

        settingsGui.Add("GroupBox", "xm y+20 w620 h105", "全局快捷键")
        this.NormalEnabledCheckbox := settingsGui.Add("CheckBox", "xm+14 yp+28 w85 h26", "普通闪念")
        this.NormalEnabledCheckbox.Value := this.Config.NormalEnabled
        this.NormalHotkeyControl := settingsGui.Add("Hotkey", "x+0 yp w90 h26", this.Config.NormalHotkey)
        this.TodoEnabledCheckbox := settingsGui.Add("CheckBox", "x+20 yp w75 h26", "保存待办")
        this.TodoEnabledCheckbox.Value := this.Config.TodoEnabled
        this.TodoHotkeyControl := settingsGui.Add("Hotkey", "x+0 yp w90 h26", this.Config.TodoHotkey)
        this.NewNoteEnabledCheckbox := settingsGui.Add("CheckBox", "x+20 yp w85 h26", "新建笔记")
        this.NewNoteEnabledCheckbox.Value := this.Config.NewNoteEnabled
        this.NewNoteHotkeyControl := settingsGui.Add("Hotkey", "x+0 yp w90 h26", this.Config.NewNoteHotkey)
        this.NormalEnabledCheckbox.OnEvent("Click", (*) => this.UpdateHotkeyControlStates())
        this.TodoEnabledCheckbox.OnEvent("Click", (*) => this.UpdateHotkeyControlStates())
        this.NewNoteEnabledCheckbox.OnEvent("Click", (*) => this.UpdateHotkeyControlStates())
        settingsGui.Add("Text", "xm+14 y+13 w580 c666666", "勾选表示启用；默认启用普通闪念和新建笔记，已启用项不得重复。")

        settingsGui.Add("GroupBox", "xm y+20 w620 h174", "内容格式、网页来源与启动")
        this.SourceUrlCheckbox := settingsGui.Add("CheckBox", "xm+14 yp+27", "自动附加网页来源网址")
        this.SourceUrlCheckbox.Value := this.Config.SourceUrlEnabled
        this.BrowserFallbackCheckbox := settingsGui.Add("CheckBox", "xm+14 y+14", "剪贴板无来源时，从当前浏览器补取网址")
        this.BrowserFallbackCheckbox.Value := this.Config.BrowserFallback
        this.StartupCheckbox := settingsGui.Add("CheckBox", "x+35 yp", "开机自启")
        this.StartupCheckbox.Value := this.Config.StartWithWindows
        this.LinkNewNoteCheckbox := settingsGui.Add("CheckBox", "xm+14 y+14", "新建笔记后，在闪念笔记中插入可点击链接")
        this.LinkNewNoteCheckbox.Value := this.Config.LinkNewNoteInFlash
        settingsGui.Add("Text", "xm+14 y+17 w75", "内容格式")
        this.ContentFormatDropDown := settingsGui.Add("DropDownList", "x+0 yp-4 w280", [
            "智能 Markdown（保留加粗）",
            "Markdown 代码块（保留格式源码）",
            "纯文本段落"
        ])
        this.ContentFormatDropDown.Choose(this.ContentFormatIndex(this.Config.ContentFormat))
        settingsGui.Add("Text", "x+12 yp+4 w190 c666666", "代码块不渲染加粗")

        settingsGui.Add("Button", "xm y+22 w110 h34 Default", "保存并应用").OnEvent("Click", (*) => this.SaveSettings())
        settingsGui.Add("Button", "x+8 yp w90 h34", "测试配置").OnEvent("Click", (*) => this.TestSettings())
        this.UsageButton := settingsGui.Add("Button", "x+8 yp w90 h34", "使用说明")
        this.UsageButton.OnEvent("Click", (*) => this.ShowUsageGuide())
        settingsGui.Add("Button", "x+8 yp w105 h34", "隐藏到托盘").OnEvent("Click", (*) => this.HideSettings())
        settingsGui.Add("Button", "x+8 yp w85 h34", "打开笔记").OnEvent("Click", (*) => this.OpenFlashNote())
        settingsGui.Add("Button", "x+8 yp w65 h34", "退出").OnEvent("Click", (*) => this.ExitApplication())

        settingsGui.OnEvent("Close", (*) => this.HideSettings())
        this.SettingsGui := settingsGui
        this.UpdateHotkeyControlStates()
        this.UpdateStatus("已启用 " this.EnabledHotkeyCount(this.Config) " 个快捷键")
    }

    ConfigFromControls() {
        return {
            Vault: Trim(this.VaultEdit.Value),
            FlashNote: Trim(this.FlashPathEdit.Value),
            NewNoteFolder: Trim(this.NewFolderEdit.Value),
            Anchor: Trim(this.AnchorEdit.Value),
            NormalHotkey: this.NormalHotkeyControl.Value,
            TodoHotkey: this.TodoHotkeyControl.Value,
            NewNoteHotkey: this.NewNoteHotkeyControl.Value,
            NormalEnabled: this.NormalEnabledCheckbox.Value ? 1 : 0,
            TodoEnabled: this.TodoEnabledCheckbox.Value ? 1 : 0,
            NewNoteEnabled: this.NewNoteEnabledCheckbox.Value ? 1 : 0,
            LinkNewNoteInFlash: this.LinkNewNoteCheckbox.Value ? 1 : 0,
            SourceUrlEnabled: this.SourceUrlCheckbox.Value ? 1 : 0,
            BrowserFallback: this.BrowserFallbackCheckbox.Value ? 1 : 0,
            AddressBarCopyFallback: 1,
            ContentFormat: this.ContentFormatFromIndex(this.ContentFormatDropDown.Value),
            StartWithWindows: this.StartupCheckbox.Value ? 1 : 0
        }
    }

    ContentFormatIndex(mode) {
        if (mode = ClipboardFormatter.CodeBlock)
            return 2
        if (mode = ClipboardFormatter.PlainText)
            return 3
        return 1
    }

    UpdateHotkeyControlStates() {
        this.NormalHotkeyControl.Enabled := !!this.NormalEnabledCheckbox.Value
        this.TodoHotkeyControl.Enabled := !!this.TodoEnabledCheckbox.Value
        this.NewNoteHotkeyControl.Enabled := !!this.NewNoteEnabledCheckbox.Value
    }

    EnabledHotkeyCount(config) {
        return (config.NormalEnabled ? 1 : 0)
            + (config.TodoEnabled ? 1 : 0)
            + (config.NewNoteEnabled ? 1 : 0)
    }

    ContentFormatFromIndex(index) {
        if (index = 2)
            return ClipboardFormatter.CodeBlock
        if (index = 3)
            return ClipboardFormatter.PlainText
        return ClipboardFormatter.SmartMarkdown
    }

    ValidateConfig(config) {
        errors := []
        if !InStr(FileExist(config.Vault), "D")
            errors.Push("Vault 根目录不存在")
        if (config.Anchor = "")
            errors.Push("插入锚点不能为空")
        if !FileExist(config.FlashNote) {
            errors.Push("闪念目标笔记不存在")
        } else {
            try {
                markdown := FlashNoteCore.ReadUtf8File(config.FlashNote)
                if (config.Anchor != "") {
                    anchorCount := FlashNoteCore.CountOccurrences(markdown, config.Anchor)
                    if (anchorCount != 1)
                        errors.Push("插入锚点数量必须为 1，当前为 " anchorCount)
                }
                file := FileOpen(config.FlashNote, "rw", "UTF-8")
                file.Close()
            } catch as err {
                errors.Push("闪念目标笔记不可读写：" this.UserMessage(err))
            }
        }
        if !InStr(FileExist(config.NewNoteFolder), "D")
            errors.Push("新建笔记目录不存在")
        if !ClipboardFormatter.IsValidMode(config.ContentFormat)
            errors.Push("内容格式配置无效")
        if InStr(FileExist(config.Vault), "D") && InStr(FileExist(config.NewNoteFolder), "D") {
            try {
                if !FlashNoteCore.IsPathInside(config.NewNoteFolder, config.Vault)
                    errors.Push("新建笔记目录必须位于 Vault 内")
            } catch as err {
                errors.Push(this.UserMessage(err))
            }
        }
        if InStr(FileExist(config.Vault), "D") && FileExist(config.FlashNote) {
            try {
                if !FlashNoteCore.IsPathInside(config.FlashNote, config.Vault)
                    errors.Push("闪念目标笔记必须位于 Vault 内")
            }
        }
        if (config.NormalEnabled && config.NormalHotkey = "")
            errors.Push("已启用的普通闪念快捷键不能为空")
        if (config.TodoEnabled && config.TodoHotkey = "")
            errors.Push("已启用的保存待办快捷键不能为空")
        if (config.NewNoteEnabled && config.NewNoteHotkey = "")
            errors.Push("已启用的新建笔记快捷键不能为空")
        if ((config.NormalEnabled && config.TodoEnabled && config.NormalHotkey = config.TodoHotkey)
            || (config.NormalEnabled && config.NewNoteEnabled && config.NormalHotkey = config.NewNoteHotkey)
            || (config.TodoEnabled && config.NewNoteEnabled && config.TodoHotkey = config.NewNoteHotkey))
            errors.Push("已启用的快捷键不能重复")
        return errors
    }

    SaveSettings() {
        candidate := this.ConfigFromControls()
        errors := this.ValidateConfig(candidate)
        if (errors.Length > 0) {
            MsgBox(this.JoinLines(errors), "设置未保存", "Iconx")
            return
        }

        hotkeyError := this.ApplyHotkeys(candidate)
        if (hotkeyError != "") {
            MsgBox(hotkeyError, "快捷键启用失败", "Iconx")
            return
        }

        try {
            this.WriteConfig(candidate)
            this.UpdateStartup(candidate.StartWithWindows)
            this.Config := candidate
            this.UpdateStatus("设置已保存，已启用 " this.EnabledHotkeyCount(candidate) " 个快捷键")
            this.Notify("设置已保存并生效")
            this.Log("settings_save", "ok", "", "none")
        } catch as err {
            MsgBox(this.UserMessage(err), "设置保存失败", "Iconx")
            this.Log("settings_save", "error", this.ErrorCode(err), "none")
        }
    }

    TestSettings() {
        candidate := this.ConfigFromControls()
        errors := this.ValidateConfig(candidate)
        if (errors.Length > 0) {
            MsgBox(this.JoinLines(errors), "配置检查未通过", "Iconx")
            return
        }
        MsgBox("配置检查通过。`n`n本次检查没有向真实笔记写入内容。", "配置检查", "Iconi")
    }

    ApplyHotkeys(config) {
        previousConfig := this.Config
        previousKeys := this.ActiveHotkeys.Clone()
        this.DisableActiveHotkeys()
        registered := []
        try {
            if config.NormalEnabled {
                this.RegisterHotkey(config.NormalHotkey, this.CaptureNormal.Bind(this))
                registered.Push(config.NormalHotkey)
            }
            if config.TodoEnabled {
                this.RegisterHotkey(config.TodoHotkey, this.CaptureTodo.Bind(this))
                registered.Push(config.TodoHotkey)
            }
            if config.NewNoteEnabled {
                this.RegisterHotkey(config.NewNoteHotkey, this.ShowNewNote.Bind(this))
                registered.Push(config.NewNoteHotkey)
            }
            this.ActiveHotkeys := registered
            this.HotkeysPaused := false
            return ""
        } catch as err {
            for key in registered {
                try Hotkey(key, "Off")
            }
            this.ActiveHotkeys := []
            if (previousKeys.Length > 0) {
                try {
                    restored := []
                    if previousConfig.NormalEnabled {
                        this.RegisterHotkey(previousConfig.NormalHotkey, this.CaptureNormal.Bind(this))
                        restored.Push(previousConfig.NormalHotkey)
                    }
                    if previousConfig.TodoEnabled {
                        this.RegisterHotkey(previousConfig.TodoHotkey, this.CaptureTodo.Bind(this))
                        restored.Push(previousConfig.TodoHotkey)
                    }
                    if previousConfig.NewNoteEnabled {
                        this.RegisterHotkey(previousConfig.NewNoteHotkey, this.ShowNewNote.Bind(this))
                        restored.Push(previousConfig.NewNoteHotkey)
                    }
                    this.ActiveHotkeys := restored
                }
            }
            return "无法启用快捷键，可能已被其他程序占用：`n" this.UserMessage(err)
        }
    }

    RegisterHotkey(key, callback) {
        if (key = "")
            throw Error("INVALID_HOTKEY|快捷键不能为空")
        Hotkey(key, callback, "On")
    }

    DisableActiveHotkeys() {
        for key in this.ActiveHotkeys {
            try Hotkey(key, "Off")
        }
        this.ActiveHotkeys := []
    }

    TogglePause() {
        if (this.ActiveHotkeys.Length = 0)
            return
        this.HotkeysPaused := !this.HotkeysPaused
        for key in this.ActiveHotkeys {
            try Hotkey(key, this.HotkeysPaused ? "Off" : "On")
        }
        this.UpdateStatus(this.HotkeysPaused ? "快捷键已暂停" : "快捷键已恢复")
        this.Notify(this.HotkeysPaused ? "快捷键已暂停" : "快捷键已恢复")
    }

    CaptureNormal(*) {
        this.CaptureToFlashNote(false)
    }

    CaptureTodo(*) {
        this.CaptureToFlashNote(true)
    }

    CaptureToFlashNote(isTodo) {
        action := isTodo ? "capture_todo" : "capture_normal"
        sourceMethod := "none"
        image := ""
        try {
            plainText := A_Clipboard
            if ImageClipboard.HasImage(plainText) {
                image := ImageClipboard.SaveToVault(this.Config.Vault, plainText)
                source := this.ResolveSourceUrl()
                sourceMethod := source.Method
                block := FlashNoteCore.BuildImageFlashBlock(image.RelativePath, source.Url, isTodo)
                FlashNoteCore.SafeInsertFile(
                    this.Config.FlashNote,
                    this.Config.Anchor,
                    block.Text,
                    block.BlockId
                )
                this.Notify(isTodo ? "图片待办已保存" : "图片闪念已保存")
                this.Log(action, "ok", "", sourceMethod)
                return
            }
            if (Trim(plainText) = "")
                throw Error("EMPTY_CLIPBOARD|剪贴板没有可保存的文字或图片")
            cfHtml := (this.Config.ContentFormat = ClipboardFormatter.SmartMarkdown
                || this.Config.ContentFormat = ClipboardFormatter.CodeBlock)
                ? BrowserSource.ReadClipboardHtml()
                : ""
            text := ClipboardFormatter.PrepareFlashText(plainText, cfHtml, this.Config.ContentFormat)
            source := this.ResolveSourceUrl()
            sourceMethod := source.Method
            block := FlashNoteCore.BuildFlashBlock(text, source.Url, isTodo, , , this.Config.ContentFormat)
            FlashNoteCore.SafeInsertFile(
                this.Config.FlashNote,
                this.Config.Anchor,
                block.Text,
                block.BlockId
            )
            message := isTodo ? "待办已保存" : "普通闪念已保存"
            this.Notify(message)
            this.Log(action, "ok", "", sourceMethod)
        } catch as err {
            this.DeleteCreatedImage(image)
            this.Notify(this.UserMessage(err), true)
            this.Log(action, "error", this.ErrorCode(err), sourceMethod)
        }
    }

    ResolveSourceUrl() {
        if !this.Config.SourceUrlEnabled
            return {Url: "", Method: "disabled"}
        return BrowserSource.GetSourceUrl(
            this.Config.BrowserFallback,
            this.Config.AddressBarCopyFallback
        )
    }

    ShowNewNote(*) {
        image := ""
        try {
            this.CloseNewNoteDialog()
            plainText := A_Clipboard
            if ImageClipboard.HasImage(plainText) {
                image := ImageClipboard.SaveToVault(this.Config.Vault, plainText)
                source := this.ResolveSourceUrl()
                suggestedTitle := "图片剪藏-" FormatTime(A_Now, "yyyyMMdd-HHmmss")
                this.OpenNewNoteDialog(image.Embed, source, suggestedTitle)
                this.PendingNewNoteImage := image
                return
            }
            cfHtml := (this.Config.ContentFormat = ClipboardFormatter.SmartMarkdown
                || this.Config.ContentFormat = ClipboardFormatter.CodeBlock)
                ? BrowserSource.ReadClipboardHtml()
                : ""
            text := ClipboardFormatter.PrepareStandalone(plainText, cfHtml, this.Config.ContentFormat)
            source := this.ResolveSourceUrl()
            this.OpenNewNoteDialog(text, source, FlashNoteCore.SuggestTitle(plainText))
        } catch as err {
            this.DeleteCreatedImage(image)
            this.Notify(this.UserMessage(err), true)
            this.Log("new_note_dialog", "error", this.ErrorCode(err), "none")
        }
    }

    OpenNewNoteDialog(text, source, suggestedTitle := "") {
        if IsObject(this.NewNoteGui) {
            try this.NewNoteGui.Destroy()
        }

        noteGui := Gui("+AlwaysOnTop +MinSize620x470", "新建 Obsidian 笔记")
        noteGui.SetFont("s10", "Microsoft YaHei UI")
        noteGui.MarginX := 16
        noteGui.MarginY := 14
        noteGui.Add("Text", "xm w80", "标题")
        title := suggestedTitle != "" ? suggestedTitle : FlashNoteCore.SuggestTitle(text)
        this.NewTitleEdit := noteGui.Add("Edit", "x+0 yp-3 w500", title)
        noteGui.Add("Text", "xm y+15 w80", "正文")
        this.NewBodyEdit := noteGui.Add("Edit", "x+0 yp-3 w500 h230 WantTab", text)
        noteGui.Add("Text", "xm y+15 w80", "来源网址")
        this.NewSourceEdit := noteGui.Add("Edit", "x+0 yp-3 w500", source.Url)
        noteGui.Add("Text", "xm y+15 w80", "保存目录")
        this.NewFolderDialogEdit := noteGui.Add("Edit", "x+0 yp-3 w410", this.Config.NewNoteFolder)
        noteGui.Add("Button", "x+8 yp-1 w80", "选择").OnEvent("Click", (*) => this.SelectDialogFolder())
        noteGui.Add("Button", "xm y+20 w120 h34 Default", "创建笔记").OnEvent("Click", (*) => this.CreateNoteFromDialog(source.Method))
        noteGui.Add("Button", "x+10 yp w90 h34", "取消").OnEvent("Click", (*) => this.CloseNewNoteDialog())
        noteGui.OnEvent("Close", (*) => this.CloseNewNoteDialog())
        this.NewNoteGui := noteGui
        noteGui.Show("w620 h470")
        this.NewTitleEdit.Focus()
    }

    CreateNoteFromDialog(sourceMethod) {
        try {
            sourceUrl := Trim(this.NewSourceEdit.Value)
            targetPath := FlashNoteCore.CreateNewNote(
                this.Config.Vault,
                Trim(this.NewFolderDialogEdit.Value),
                this.NewTitleEdit.Value,
                this.NewBodyEdit.Value,
                sourceUrl
            )
            this.LastCreatedNote := targetPath
            this.PendingNewNoteImage := ""
            fileName := ""
            SplitPath(targetPath, &fileName)
            if this.Config.LinkNewNoteInFlash {
                try {
                    linkBlock := FlashNoteCore.BuildNewNoteLinkBlock(this.Config.Vault, targetPath, sourceUrl)
                    FlashNoteCore.SafeInsertFile(
                        this.Config.FlashNote,
                        this.Config.Anchor,
                        linkBlock.Text,
                        linkBlock.BlockId
                    )
                } catch as linkError {
                    this.CloseNewNoteDialog()
                    MsgBox(
                        "笔记已创建：`n" targetPath
                            . "`n`n但写入闪念笔记的链接失败：`n" this.UserMessage(linkError),
                        "笔记已创建，链接未写入",
                        "Icon!"
                    )
                    this.Log("create_note_link", "error", this.ErrorCode(linkError), sourceMethod)
                    return
                }
            }
            this.CloseNewNoteDialog()
            this.Notify(this.Config.LinkNewNoteInFlash ? "笔记已创建并写入闪念链接：" fileName : "笔记已创建：" fileName)
            this.Log("create_note", "ok", "", sourceMethod)
        } catch as err {
            MsgBox(this.UserMessage(err), "新建笔记失败", "Iconx")
            this.Log("create_note", "error", this.ErrorCode(err), sourceMethod)
        }
    }

    CloseNewNoteDialog() {
        if IsObject(this.NewNoteGui) {
            try this.NewNoteGui.Destroy()
        }
        this.NewNoteGui := ""
        this.DeleteCreatedImage(this.PendingNewNoteImage)
        this.PendingNewNoteImage := ""
    }

    DeleteCreatedImage(image) {
        if IsObject(image) && image.Created && FileExist(image.FullPath) {
            try FileDelete(image.FullPath)
        }
    }

    SelectDialogFolder() {
        selected := DirSelect(this.NewFolderDialogEdit.Value, 0, "选择新建笔记目录")
        if (selected != "")
            this.NewFolderDialogEdit.Value := selected
    }

    SelectFlashNote() {
        SplitPath(this.FlashPathEdit.Value, , &initialDir)
        selected := FileSelect(3, initialDir, "选择闪念目标笔记", "Markdown (*.md)")
        if (selected != "")
            this.FlashPathEdit.Value := selected
    }

    SelectNewNoteFolder() {
        selected := DirSelect(this.NewFolderEdit.Value, 0, "选择新建笔记默认目录")
        if (selected != "")
            this.NewFolderEdit.Value := selected
    }

    SelectVault() {
        selected := DirSelect(this.VaultEdit.Value, 0, "选择 Obsidian Vault 根目录")
        if (selected != "")
            this.VaultEdit.Value := selected
    }

    ModifyAnchor() {
        result := InputBox(
            "请输入目标笔记中完整且唯一的插入锚点。`n保存时会验证它恰好出现一次。",
            "修改插入锚点",
            "w620 h150",
            this.AnchorEdit.Value
        )
        if (result.Result != "OK")
            return
        anchor := Trim(result.Value)
        if (anchor = "") {
            MsgBox("插入锚点不能为空。", "锚点未修改", "Iconx")
            return
        }
        this.AnchorEdit.Value := anchor
        this.UpdateStatus("插入锚点待保存，请点击“保存并应用”")
    }

    UpdateStartup(enabled) {
        if enabled {
            args := Chr(34) A_ScriptFullPath Chr(34)
            FileCreateShortcut(A_AhkPath, this.StartupShortcut, A_ScriptDir, args, "大尾巴闪念 PC 版")
        } else if FileExist(this.StartupShortcut) {
            FileDelete(this.StartupShortcut)
        }
    }

    ShowUsageGuide() {
        if IsObject(this.UsageGui) {
            try {
                this.UsageGui.Show()
                WinActivate("ahk_id " this.UsageGui.Hwnd)
                return
            }
        }

        usageGui := Gui("+MinSize680x560", "大尾巴闪念 PC 版使用说明")
        usageGui.SetFont("s10", "Microsoft YaHei UI")
        usageGui.MarginX := 18
        usageGui.MarginY := 16
        usageGui.Add("Text", "xm w640 c1F4E79", "复制文字或图片后，按已启用的快捷键即可保存到 Obsidian")
        guide := "一、默认快捷键`r`n"
            . "1. Ctrl + Alt + S：保存普通闪念（默认启用）`r`n"
            . "2. Ctrl + Alt + T：保存待办（默认关闭）`r`n"
            . "3. Ctrl + Alt + N：新建独立笔记（默认启用）`r`n`r`n"
            . "二、普通闪念`r`n"
            . "默认使用 Markdown 代码块。网页剪藏会增加“来自域名网页的剪藏。”，并保留来源网址。`r`n"
            . "复制图片或图片文件后保存，会复制到 Vault 的 Obsidian 附件目录，并插入可见图片。`r`n`r`n"
            . "三、保存待办`r`n"
            . "生成 Obsidian Tasks 可识别的未完成任务；需要时先在设置中勾选启用。`r`n`r`n"
            . "四、新建笔记`r`n"
            . "弹窗中可修改标题、正文、来源网址和目录。默认创建后，会在闪念目标笔记锚点下插入可点击的 Obsidian 链接。`r`n`r`n"
            . "五、设置与安全`r`n"
            . "路径只能通过“选择”修改，插入锚点只能通过“修改”更新。保存前可点击“测试配置”；锚点必须在目标笔记中恰好出现一次。"
        this.UsageText := usageGui.Add("Text", "xm y+12 w640 h450", guide)
        usageGui.Add("Button", "xm y+14 w90 h32 Default", "关闭").OnEvent("Click", (*) => this.CloseUsageGuide())
        usageGui.OnEvent("Close", (*) => this.CloseUsageGuide())
        this.UsageGui := usageGui
        usageGui.Show("w680 h560")
    }

    CloseUsageGuide() {
        if IsObject(this.UsageGui) {
            try this.UsageGui.Destroy()
        }
        this.UsageGui := ""
    }

    ShowSettings() {
        this.SettingsGui.Show("w660 h650")
        WinActivate("ahk_id " this.SettingsGui.Hwnd)
    }

    HideSettings() {
        this.SettingsGui.Hide()
        this.Notify("已隐藏到托盘")
    }

    UpdateStatus(message, isError := false) {
        if IsObject(this.StatusText) {
            this.StatusText.Text := "状态：" message "　|　AutoHotkey v" A_AhkVersion
            this.StatusText.SetFont(isError ? "cB42318" : "c2E7D32")
        }
    }

    OpenFlashNote() {
        this.OpenPath(this.Config.FlashNote)
    }

    OpenNewNoteFolder() {
        this.OpenPath(this.Config.NewNoteFolder)
    }

    OpenPath(path) {
        try Run(path)
        catch as err {
            MsgBox("无法打开：`n" path "`n`n" this.UserMessage(err), "打开失败", "Iconx")
        }
    }

    Notify(message, isError := false) {
        options := isError ? "Iconx Mute" : "Iconi Mute"
        TrayTip(message, "大尾巴闪念 PC 版", options)
        SetTimer(() => TrayTip(), -2500)
    }

    Log(action, status, code := "", sourceMethod := "none") {
        try {
            DirCreate(this.LogDir)
            if FileExist(this.LogPath) {
                tooLarge := FileGetSize(this.LogPath) >= 1048576
                tooOld := DateDiff(A_Now, FileGetTime(this.LogPath, "M"), "Days") >= 7
                if (tooLarge || tooOld) {
                    archive := this.LogPath ".1"
                    if FileExist(archive)
                        FileDelete(archive)
                    FileMove(this.LogPath, archive)
                }
            }
            line := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " action=" action " status=" status " code=" (code = "" ? "-" : code) " source=" sourceMethod "`n"
            FileAppend(line, this.LogPath, "UTF-8-RAW")
        }
    }

    ErrorCode(err) {
        separator := InStr(err.Message, "|")
        return separator ? SubStr(err.Message, 1, separator - 1) : "UNEXPECTED"
    }

    UserMessage(err) {
        separator := InStr(err.Message, "|")
        return separator ? SubStr(err.Message, separator + 1) : err.Message
    }

    JoinLines(items) {
        text := ""
        for item in items
            text .= (text = "" ? "" : "`n") "• " item
        return text
    }

    ExitApplication() {
        this.CloseNewNoteDialog()
        this.Log("app_exit", "ok", "", "none")
        ExitApp()
    }
}

headlessCheck := false
uiSmokeCheck := false
newNoteSmokeCheck := false
checkMarker := ""
for argIndex, argValue in A_Args {
    if (argValue = "--headless-check") {
        headlessCheck := true
        if (argIndex < A_Args.Length)
            checkMarker := A_Args[argIndex + 1]
        break
    }
    if (argValue = "--ui-smoke-check") {
        uiSmokeCheck := true
        if (argIndex < A_Args.Length)
            checkMarker := A_Args[argIndex + 1]
        break
    }
    if (argValue = "--new-note-smoke-check") {
        newNoteSmokeCheck := true
        if (argIndex < A_Args.Length)
            checkMarker := A_Args[argIndex + 1]
        break
    }
}
if headlessCheck {
    if (checkMarker != "")
        FlashNoteCore.WriteUtf8File(checkMarker, "OK`n", false)
    ExitApp(0)
}

global DabaweiFlashNoteApp := FlashNoteApp()
if (uiSmokeCheck || newNoteSmokeCheck) {
    try {
        DabaweiFlashNoteApp.Start()
        if (DabaweiFlashNoteApp.ContentFormatDropDown.Value != DabaweiFlashNoteApp.ContentFormatIndex(DabaweiFlashNoteApp.Config.ContentFormat))
            throw Error("content format dropdown mismatch")
        if (DabaweiFlashNoteApp.Config.ContentFormat != ClipboardFormatter.CodeBlock)
            throw Error("markdown code block is not the default mode")
        if (DabaweiFlashNoteApp.NormalEnabledCheckbox.Value != 1
            || DabaweiFlashNoteApp.TodoEnabledCheckbox.Value != 0
            || DabaweiFlashNoteApp.NewNoteEnabledCheckbox.Value != 1)
            throw Error("default hotkey switches mismatch")
        if (DabaweiFlashNoteApp.ActiveHotkeys.Length != 2)
            throw Error("enabled hotkey registration count mismatch")
        if DabaweiFlashNoteApp.TodoHotkeyControl.Enabled
            throw Error("disabled todo hotkey control remains enabled")
        hotkeyRowPositions := []
        for control in [
            DabaweiFlashNoteApp.NormalEnabledCheckbox,
            DabaweiFlashNoteApp.NormalHotkeyControl,
            DabaweiFlashNoteApp.TodoEnabledCheckbox,
            DabaweiFlashNoteApp.TodoHotkeyControl,
            DabaweiFlashNoteApp.NewNoteEnabledCheckbox,
            DabaweiFlashNoteApp.NewNoteHotkeyControl
        ] {
            control.GetPos(&controlX, &controlY, &controlWidth, &controlHeight)
            hotkeyRowPositions.Push({Y: controlY, Height: controlHeight})
        }
        for position in hotkeyRowPositions {
            if (position.Y != hotkeyRowPositions[1].Y || position.Height != 26)
                throw Error("hotkey switch row alignment mismatch")
        }
        if (DabaweiFlashNoteApp.LinkNewNoteCheckbox.Value != 1)
            throw Error("new note link switch is not enabled")
        DabaweiFlashNoteApp.ShowUsageGuide()
        if !InStr(DabaweiFlashNoteApp.UsageText.Text, "Ctrl + Alt + S")
            || !InStr(DabaweiFlashNoteApp.UsageText.Text, "复制图片")
            throw Error("usage guide content missing")
        DabaweiFlashNoteApp.CloseUsageGuide()
        for control in [
            DabaweiFlashNoteApp.FlashPathEdit,
            DabaweiFlashNoteApp.NewFolderEdit,
            DabaweiFlashNoteApp.VaultEdit,
            DabaweiFlashNoteApp.AnchorEdit
        ] {
            style := DllCall("GetWindowLongPtr", "Ptr", control.Hwnd, "Int", -16, "Ptr")
            if !(style & 0x800)
                throw Error("protected setting is not read-only")
        }
        if (DabaweiFlashNoteApp.AnchorEdit.Value != DabaweiFlashNoteApp.Config.Anchor)
            throw Error("anchor setting mismatch")
        missingAnchorConfig := DabaweiFlashNoteApp.ConfigFromControls()
        missingAnchorConfig.Anchor := "<!-- DABAWEI_MISSING_ANCHOR_SMOKE -->"
        missingAnchorRejected := false
        for message in DabaweiFlashNoteApp.ValidateConfig(missingAnchorConfig) {
            if InStr(message, "插入锚点数量必须为 1") {
                missingAnchorRejected := true
                break
            }
        }
        if !missingAnchorRejected
            throw Error("missing anchor was not rejected")
        emptyAnchorConfig := DabaweiFlashNoteApp.ConfigFromControls()
        emptyAnchorConfig.Anchor := ""
        emptyAnchorRejected := false
        for message in DabaweiFlashNoteApp.ValidateConfig(emptyAnchorConfig) {
            if (message = "插入锚点不能为空") {
                emptyAnchorRejected := true
                break
            }
        }
        if !emptyAnchorRejected
            throw Error("empty anchor was not rejected")
        if newNoteSmokeCheck {
            sampleText := "验收用新建笔记`n第二行"
            DabaweiFlashNoteApp.OpenNewNoteDialog(sampleText, {Url: "https://example.com/acceptance", Method: "test"})
            if (DabaweiFlashNoteApp.NewBodyEdit.Value != sampleText)
                throw Error("new note body mismatch")
            if (DabaweiFlashNoteApp.NewSourceEdit.Value != "https://example.com/acceptance")
                throw Error("new note source mismatch")
        }
        Sleep(250)
        if (checkMarker != "")
            FlashNoteCore.WriteUtf8File(checkMarker, "OK hwnd=" (newNoteSmokeCheck ? DabaweiFlashNoteApp.NewNoteGui.Hwnd : DabaweiFlashNoteApp.SettingsGui.Hwnd) "`n", false)
        ExitApp(0)
    } catch as err {
        if (checkMarker != "")
            FlashNoteCore.WriteUtf8File(checkMarker, "ERROR " err.Message "`n", false)
        ExitApp(1)
    }
} else {
    DabaweiFlashNoteApp.Start()
}
