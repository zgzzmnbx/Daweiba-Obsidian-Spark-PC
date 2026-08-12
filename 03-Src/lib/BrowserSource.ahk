#Requires AutoHotkey v2.0

class BrowserSource {
    static SupportedBrowsers := Map(
        "chrome.exe", true,
        "msedge.exe", true,
        "firefox.exe", true
    )

    static GetSourceUrl(allowBrowserFallback := true, allowAddressBarCopy := true) {
        url := this.ReadClipboardSourceUrl()
        if this.IsHttpUrl(url)
            return {Url: url, Method: "clipboard_source_url"}

        if !allowBrowserFallback || !this.IsSupportedBrowserActive()
            return {Url: "", Method: "none"}

        try url := this.ReadActiveBrowserUrlUIA()
        catch
            url := ""
        if this.IsHttpUrl(url)
            return {Url: url, Method: "browser_uia"}

        if allowAddressBarCopy {
            url := this.ReadAddressBarWithClipboardRestore()
            if this.IsHttpUrl(url)
                return {Url: url, Method: "address_bar_copy"}
        }
        return {Url: "", Method: "none"}
    }

    static IsHttpUrl(url) {
        return RegExMatch(Trim(url), "i)^https?://[^\s]+$") = 1
    }

    static ParseSourceUrl(cfHtml) {
        if RegExMatch(cfHtml, "im)^SourceURL:\h*(https?://\S+)", &match)
            return Trim(match[1], " `t`r`n")
        return ""
    }

    static ReadClipboardSourceUrl() {
        return this.ParseSourceUrl(this.ReadClipboardHtml())
    }

    static ReadClipboardHtml() {
        htmlFormat := DllCall("User32\RegisterClipboardFormatW", "Str", "HTML Format", "UInt")
        opened := false
        dataHandle := 0
        dataPointer := 0
        Loop 5 {
            if DllCall("User32\OpenClipboard", "Ptr", A_ScriptHwnd, "Int") {
                opened := true
                break
            }
            Sleep(20)
        }
        if !opened
            return ""

        try {
            if !DllCall("User32\IsClipboardFormatAvailable", "UInt", htmlFormat, "Int")
                return ""
            dataHandle := DllCall("User32\GetClipboardData", "UInt", htmlFormat, "Ptr")
            if !dataHandle
                return ""
            dataPointer := DllCall("Kernel32\GlobalLock", "Ptr", dataHandle, "Ptr")
            if !dataPointer
                return ""
            return StrGet(dataPointer, "UTF-8")
        } finally {
            if dataPointer
                DllCall("Kernel32\GlobalUnlock", "Ptr", dataHandle)
            DllCall("User32\CloseClipboard")
        }
    }

    static IsSupportedBrowserActive() {
        try processName := StrLower(WinGetProcessName("A"))
        catch
            return false
        return this.SupportedBrowsers.Has(processName)
    }

    static ReadActiveBrowserUrlUIA(timeoutMs := 650) {
        if !this.IsSupportedBrowserActive()
            return ""
        browserHwnd := WinGetID("A")
        workerPath := this.WorkerScriptPath()
        if !FileExist(workerPath)
            return ""

        outputPath := A_Temp "\dabawei-flashnote-uia-" DllCall("Kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount "-" Random(1000, 9999) ".txt"
        command := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut " Chr(34) workerPath Chr(34) " " browserHwnd " " Chr(34) outputPath Chr(34)
        workerPid := 0
        try {
            Run(command, , "Hide", &workerPid)
            deadline := A_TickCount + Max(100, timeoutMs)
            Loop {
                if FileExist(outputPath)
                    return Trim(FileRead(outputPath, "UTF-8"), " `t`r`n")
                if !ProcessExist(workerPid)
                    return ""
                if (A_TickCount >= deadline) {
                    try ProcessClose(workerPid)
                    return ""
                }
                Sleep(15)
            }
        } catch {
            if (workerPid && ProcessExist(workerPid))
                try ProcessClose(workerPid)
            return ""
        } finally {
            if FileExist(outputPath)
                try FileDelete(outputPath)
        }
    }

    static WorkerScriptPath() {
        SplitPath(A_LineFile, , &libraryDir)
        return libraryDir "\BrowserUrlWorker.ahk"
    }

    static ReadBrowserUrlUIARaw(browserHwnd) {
        processName := StrLower(WinGetProcessName("ahk_id " browserHwnd))
        if !this.SupportedBrowsers.Has(processName)
            return ""

        ; Minimal direct use of the public Windows UI Automation COM API.
        ; Control type differs between Chromium and Firefox address bars.
        UIA_ControlTypePropertyId := 30003
        UIA_ValueValuePropertyId := 30045
        UIA_DocumentControlTypeId := 50030
        UIA_EditControlTypeId := 50004
        TreeScope_Descendants := 4
        controlType := processName = "firefox.exe" ? UIA_EditControlTypeId : UIA_DocumentControlTypeId

        automation := ComObject(
            "{FF48DBA4-60EF-4201-AA87-54103EEF594E}",
            "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
        )
        root := ComValue(13, 0)
        condition := ComValue(13, 0)
        element := ComValue(13, 0)
        valueVariant := Buffer(8 + 2 * A_PtrSize, 0)

        result := ComCall(6, automation, "Ptr", browserHwnd, "Ptr*", root)
        if (result != 0 || !root.Ptr)
            return ""

        variant := Buffer(8 + 2 * A_PtrSize, 0)
        NumPut("UShort", 3, variant, 0)
        NumPut("Ptr", controlType, variant, 8)
        if (A_PtrSize = 8) {
            result := ComCall(23, automation, "UInt", UIA_ControlTypePropertyId, "Ptr", variant, "Ptr*", condition)
        } else {
            result := ComCall(23, automation, "UInt", UIA_ControlTypePropertyId,
                "UInt64", NumGet(variant, 0, "UInt64"),
                "UInt64", NumGet(variant, 8, "UInt64"),
                "Ptr*", condition)
        }
        if (result != 0 || !condition.Ptr)
            return ""

        result := ComCall(5, root, "UInt", TreeScope_Descendants, "Ptr", condition, "Ptr*", element)
        if (result != 0 || !element.Ptr)
            return ""

        result := ComCall(10, element, "UInt", UIA_ValueValuePropertyId, "Ptr", valueVariant)
        if (result != 0)
            return ""

        try {
            valuePointer := NumGet(valueVariant, 8, "Ptr")
            return valuePointer ? Trim(StrGet(valuePointer, "UTF-16")) : ""
        } finally {
            DllCall("OleAut32\VariantClear", "Ptr", valueVariant)
        }
    }

    static ReadAddressBarWithClipboardRestore() {
        if !this.IsSupportedBrowserActive()
            return ""

        snapshot := ClipboardAll()
        restored := false
        url := ""
        try {
            A_Clipboard := ""
            Send("^l")
            Sleep(40)
            Send("^c")
            if ClipWait(0.8, 0)
                url := Trim(A_Clipboard)
            Send("{Esc}")
        } finally {
            try {
                A_Clipboard := snapshot
                if snapshot.Size = 0 || ClipWait(1.0, 1)
                    restored := true
            }
        }
        if !restored
            throw Error("CLIPBOARD_RESTORE_FAILED|恢复剪贴板失败，已取消保存")
        return url
    }
}
