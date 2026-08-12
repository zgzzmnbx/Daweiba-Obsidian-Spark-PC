#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\03-Src\lib\BrowserSource.ahk"

if (A_Args.Length < 2)
    ExitApp(2)

browserHwnd := Integer(A_Args[1])
resultPath := A_Args[2]
previousHwnd := WinGetID("A")
uiaUrl := ""
uiaError := ""
fallbackUrl := ""
fallbackError := ""

WriteStage(stage) {
    global resultPath
    FileAppend("STAGE=" stage "`n", resultPath, "UTF-8-RAW")
}

try {
    WriteStage("activate")
    WinActivate("ahk_id " browserHwnd)
    if !WinWaitActive("ahk_id " browserHwnd, , 2)
        throw Error("browser window did not become active")
    WriteStage("uia_start")
    uiaUrl := BrowserSource.ReadActiveBrowserUrlUIA()
    WriteStage("uia_done")
} catch as err {
    uiaError := err.Message
}

WriteStage("fallback_start")
try fallbackUrl := BrowserSource.ReadAddressBarWithClipboardRestore()
catch as err
    fallbackError := err.Message
WriteStage("fallback_done")

try WinActivate("ahk_id " previousHwnd)

result := "UIA_VALID=" BrowserSource.IsHttpUrl(uiaUrl) "`n"
    . "UIA_LENGTH=" StrLen(uiaUrl) "`n"
    . "UIA_ERROR=" uiaError "`n"
    . "FALLBACK_VALID=" BrowserSource.IsHttpUrl(fallbackUrl) "`n"
    . "FALLBACK_LENGTH=" StrLen(fallbackUrl) "`n"
    . "FALLBACK_ERROR=" fallbackError "`n"
FileAppend(result, resultPath, "UTF-8-RAW")
ExitApp(BrowserSource.IsHttpUrl(uiaUrl) || BrowserSource.IsHttpUrl(fallbackUrl) ? 0 : 1)
