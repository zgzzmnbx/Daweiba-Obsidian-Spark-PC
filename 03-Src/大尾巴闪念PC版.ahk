#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

#Include "lib\FlashNoteCore.ahk"
#Include "lib\ClipboardFormatter.ahk"
#Include "lib\ConfigStore.ahk"
#Include "lib\BrowserSource.ahk"

class FlashNoteApp {
    static Version := "0.3.2"

    __New() {
        SplitPath(A_ScriptDir, , &projectRoot)
        this.ProjectRoot := projectRoot
        this.ConfigPath := projectRoot "\config.ini"
        this.LogDir := projectRoot "\logs"
        this.LogPath := this.LogDir "\flashnote-pc.log"
        this.StartupShortcut := A_Startup "\大尾巴闪念PC版.lnk"
        this.SettingsGui := ""
        this.NewNoteGui := ""
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
        A_TrayMenu.Add("暂停/恢复快捷键", (*) => this.TogglePause())
        A_TrayMenu.Add()
        A_TrayMenu.Add("打开闪念目标笔记", (*) => this.OpenFlashNote())
        A_TrayMenu.Add("打开新建笔记目录", (*) => this.OpenNewNoteFolder())
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", (*) => this.ExitApplication())
        A_TrayMenu.Default := "打开设置"
    }

    BuildSettingsGui() {
        settingsGui := Gui("+MinSize660x600", "大尾巴闪念 PC 版 v" FlashNoteApp.Version)
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
        settingsGui.Add("Text", "xm+14 yp+29 w95", "普通闪念")
        this.NormalHotkeyControl := settingsGui.Add("Hotkey", "x+0 yp-4 w110", this.Config.NormalHotkey)
        settingsGui.Add("Text", "x+28 yp+4 w70", "保存待办")
        this.TodoHotkeyControl := settingsGui.Add("Hotkey", "x+0 yp-4 w110", this.Config.TodoHotkey)
        settingsGui.Add("Text", "x+28 yp+4 w70", "新建笔记")
        this.NewNoteHotkeyControl := settingsGui.Add("Hotkey", "x+0 yp-4 w110", this.Config.NewNoteHotkey)
        settingsGui.Add("Text", "xm+14 y+16 w580 c666666", "默认：Ctrl+Alt+S / Ctrl+Alt+T / Ctrl+Alt+N；不得重复。")

        settingsGui.Add("GroupBox", "xm y+20 w620 h145", "内容格式、网页来源与启动")
        this.SourceUrlCheckbox := settingsGui.Add("CheckBox", "xm+14 yp+27", "自动附加网页来源网址")
        this.SourceUrlCheckbox.Value := this.Config.SourceUrlEnabled
        this.BrowserFallbackCheckbox := settingsGui.Add("CheckBox", "xm+14 y+14", "剪贴板无来源时，从当前浏览器补取网址")
        this.BrowserFallbackCheckbox.Value := this.Config.BrowserFallback
        this.StartupCheckbox := settingsGui.Add("CheckBox", "x+35 yp", "开机自启")
        this.StartupCheckbox.Value := this.Config.StartWithWindows
        settingsGui.Add("Text", "xm+14 y+17 w75", "内容格式")
        this.ContentFormatDropDown := settingsGui.Add("DropDownList", "x+0 yp-4 w280", [
            "智能 Markdown（保留加粗）",
            "Markdown 代码块（保留格式源码）",
            "纯文本段落"
        ])
        this.ContentFormatDropDown.Choose(this.ContentFormatIndex(this.Config.ContentFormat))
        settingsGui.Add("Text", "x+12 yp+4 w190 c666666", "代码块不渲染加粗")

        settingsGui.Add("Button", "xm y+22 w125 h34 Default", "保存并应用").OnEvent("Click", (*) => this.SaveSettings())
        settingsGui.Add("Button", "x+10 yp w110 h34", "测试配置").OnEvent("Click", (*) => this.TestSettings())
        settingsGui.Add("Button", "x+10 yp w120 h34", "隐藏到托盘").OnEvent("Click", (*) => this.HideSettings())
        settingsGui.Add("Button", "x+10 yp w90 h34", "打开笔记").OnEvent("Click", (*) => this.OpenFlashNote())
        settingsGui.Add("Button", "x+10 yp w90 h34", "退出").OnEvent("Click", (*) => this.ExitApplication())

        settingsGui.OnEvent("Close", (*) => this.HideSettings())
        this.SettingsGui := settingsGui
        this.UpdateStatus("快捷键已启用")
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
        hotkeys := [config.NormalHotkey, config.TodoHotkey, config.NewNoteHotkey]
        for key in hotkeys {
            if (key = "")
                errors.Push("三组快捷键都不能为空")
        }
        if (config.NormalHotkey = config.TodoHotkey || config.NormalHotkey = config.NewNoteHotkey || config.TodoHotkey = config.NewNoteHotkey)
            errors.Push("三组快捷键不能重复")
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
            this.UpdateStatus("设置已保存，三个快捷键正在监听")
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
            this.RegisterHotkey(config.NormalHotkey, this.CaptureNormal.Bind(this))
            registered.Push(config.NormalHotkey)
            this.RegisterHotkey(config.TodoHotkey, this.CaptureTodo.Bind(this))
            registered.Push(config.TodoHotkey)
            this.RegisterHotkey(config.NewNoteHotkey, this.ShowNewNote.Bind(this))
            registered.Push(config.NewNoteHotkey)
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
                    this.RegisterHotkey(previousConfig.NormalHotkey, this.CaptureNormal.Bind(this))
                    this.RegisterHotkey(previousConfig.TodoHotkey, this.CaptureTodo.Bind(this))
                    this.RegisterHotkey(previousConfig.NewNoteHotkey, this.ShowNewNote.Bind(this))
                    this.ActiveHotkeys := previousKeys
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
        try {
            plainText := A_Clipboard
            if (Trim(plainText) = "")
                throw Error("EMPTY_CLIPBOARD|剪贴板没有可保存的文字")
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
        try {
            plainText := A_Clipboard
            cfHtml := (this.Config.ContentFormat = ClipboardFormatter.SmartMarkdown
                || this.Config.ContentFormat = ClipboardFormatter.CodeBlock)
                ? BrowserSource.ReadClipboardHtml()
                : ""
            text := ClipboardFormatter.PrepareStandalone(plainText, cfHtml, this.Config.ContentFormat)
            source := this.ResolveSourceUrl()
            this.OpenNewNoteDialog(text, source, FlashNoteCore.SuggestTitle(plainText))
        } catch as err {
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
            targetPath := FlashNoteCore.CreateNewNote(
                this.Config.Vault,
                Trim(this.NewFolderDialogEdit.Value),
                this.NewTitleEdit.Value,
                this.NewBodyEdit.Value,
                Trim(this.NewSourceEdit.Value)
            )
            this.LastCreatedNote := targetPath
            fileName := ""
            SplitPath(targetPath, &fileName)
            this.CloseNewNoteDialog()
            this.Notify("笔记已创建：" fileName)
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

    ShowSettings() {
        this.SettingsGui.Show("w660 h600")
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
