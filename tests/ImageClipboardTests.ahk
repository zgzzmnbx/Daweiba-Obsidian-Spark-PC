#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\03-Src\lib\FlashNoteCore.ahk"
#Include "..\03-Src\lib\ClipboardFormatter.ahk"
#Include "..\03-Src\lib\ImageClipboard.ahk"

resultPath := A_ScriptDir "\..\Codex-Temp\image-clipboard-test-result.txt"
testRoot := A_ScriptDir "\..\Codex-Temp\image-clipboard-test"
snapshot := ClipboardAll()
hBitmap := 0

try {
    if InStr(FileExist(testRoot), "D")
        DirDelete(testRoot, true)
    DirCreate(testRoot "\.obsidian")
    FlashNoteCore.WriteUtf8File(testRoot "\.obsidian\app.json", "{" Chr(34) "attachmentFolderPath" Chr(34) ":" Chr(34) "assets" Chr(34) "}", false)

    screenDc := DllCall("User32\GetDC", "Ptr", 0, "Ptr")
    try hBitmap := DllCall("Gdi32\CreateCompatibleBitmap", "Ptr", screenDc, "Int", 8, "Int", 8, "Ptr")
    finally DllCall("User32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    if !hBitmap
        throw Error("无法创建测试位图")

    if !DllCall("User32\OpenClipboard", "Ptr", A_ScriptHwnd, "Int")
        throw Error("无法打开剪贴板")
    try {
        DllCall("User32\EmptyClipboard")
        if !DllCall("User32\SetClipboardData", "UInt", 2, "Ptr", hBitmap, "Ptr")
            throw Error("无法写入测试位图")
        hBitmap := 0
    } finally {
        DllCall("User32\CloseClipboard")
    }

    saved := ImageClipboard.SaveToVault(testRoot, "", "20260812154000", "4c6d")
    if !FileExist(saved.FullPath) || FileGetSize(saved.FullPath) <= 0
        throw Error("位图未保存为 PNG")
    if (saved.RelativePath != "assets/大尾巴闪念图片-20260812-154000-4c6d.png")
        throw Error("附件相对路径不正确：" saved.RelativePath)
    pathVault := testRoot "\path-vault"
    DirCreate(pathVault "\.obsidian")
    FlashNoteCore.WriteUtf8File(pathVault "\.obsidian\app.json", "{" Chr(34) "attachmentFolderPath" Chr(34) ":" Chr(34) "assets" Chr(34) "}", false)
    copied := ImageClipboard.SaveToVault(pathVault, saved.FullPath, "20260812154100", "5d7e")
    if !FileExist(copied.FullPath) || FileGetSize(copied.FullPath) != FileGetSize(saved.FullPath)
        throw Error("有效 PNG 路径未复制到另一个 Vault")
    if (copied.Embed != "![[assets/大尾巴闪念图片-20260812-154100-5d7e.png|300]]")
        throw Error("有效 PNG 路径未生成 Obsidian 嵌入")
    FlashNoteCore.WriteUtf8File(resultPath, "PASS raw_bitmap_to_png_and_image_path " FileGetSize(saved.FullPath) " bytes`n", false)
    ExitApp(0)
} catch as err {
    try FlashNoteCore.WriteUtf8File(resultPath, "FAIL " err.Message "`nWHAT=" err.What "`nLINE=" err.Line "`n", false)
    ExitApp(1)
} finally {
    if hBitmap
        DllCall("Gdi32\DeleteObject", "Ptr", hBitmap)
    try A_Clipboard := snapshot
}
