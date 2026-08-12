#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\03-Src\lib\FlashNoteCore.ahk"

if (A_Args.Length < 3)
    ExitApp(2)

vaultPath := A_Args[1]
noteFolder := A_Args[2]
resultPath := A_Args[3]
try {
    notePath := FlashNoteCore.CreateNewNote(
        vaultPath,
        noteFolder,
        "【验收测试】大尾巴闪念PC版-20991231",
        "这是新建笔记真实 Vault 验收内容。`n验收后移入 Obsidian 回收站。",
        "https://example.com/dabawei-new-note-acceptance",
        "20991231235957"
    )
    try FileDelete(resultPath)
    FileAppend(notePath "`n", resultPath, "UTF-8-RAW")
    ExitApp(0)
} catch as err {
    try FileDelete(resultPath)
    FileAppend("ERROR " err.Message "`n", resultPath, "UTF-8-RAW")
    ExitApp(1)
}
