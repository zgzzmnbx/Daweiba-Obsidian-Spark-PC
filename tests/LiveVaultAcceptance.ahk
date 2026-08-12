#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\03-Src\lib\FlashNoteCore.ahk"

if (A_Args.Length < 3)
    ExitApp(2)

action := A_Args[1]
targetPath := A_Args[2]
resultPath := A_Args[3]
normal := FlashNoteCore.BuildFlashBlock(
    "[大尾巴闪念PC版自动验收-NORMAL]",
    "https://example.com/dabawei-live-acceptance",
    false,
    "20991231235958",
    "a11c"
)
todo := FlashNoteCore.BuildFlashBlock(
    "[大尾巴闪念PC版自动验收-TODO]",
    "https://example.com/dabawei-live-acceptance",
    true,
    "20991231235959",
    "b22d"
)

try {
    if (action = "insert") {
        FlashNoteCore.SafeInsertFile(targetPath, FlashNoteCore.DefaultAnchor, normal.Text, normal.BlockId)
        FlashNoteCore.SafeInsertFile(targetPath, FlashNoteCore.DefaultAnchor, todo.Text, todo.BlockId)
        WriteResult("OK INSERT normal=" normal.BlockId " todo=" todo.BlockId)
        ExitApp(0)
    }
    if (action = "rollback") {
        RollbackBlocks(targetPath, [normal, todo])
        WriteResult("OK ROLLBACK normal=" normal.BlockId " todo=" todo.BlockId)
        ExitApp(0)
    }
    throw Error("unknown action")
} catch as err {
    WriteResult("ERROR " err.Message)
    ExitApp(1)
}

RollbackBlocks(path, blocks) {
    Loop 3 {
        original := FlashNoteCore.ReadUtf8File(path)
        cleaned := original
        for block in blocks {
            blockCount := FlashNoteCore.CountOccurrences(cleaned, block.Text)
            if (blockCount > 1)
                throw Error("ROLLBACK_BLOCK_COUNT|验收块数量异常，停止自动回滚")
            if (blockCount = 1) {
                replaceCount := 0
                cleaned := StrReplace(cleaned, block.Text, "", true, &replaceCount, 1)
            }
        }
        if (cleaned = original)
            return
        withBom := FlashNoteCore.HasUtf8Bom(path)
        tempPath := FlashNoteCore.MakeTempPath(path)
        try {
            FlashNoteCore.WriteUtf8File(tempPath, cleaned, withBom)
            if (FlashNoteCore.ReadUtf8File(path) != original)
                continue
            FlashNoteCore.AtomicMove(tempPath, path, true)
            saved := FlashNoteCore.ReadUtf8File(path)
            for block in blocks {
                if InStr(saved, block.BlockId)
                    throw Error("ROLLBACK_VERIFY|验收块回滚校验失败")
            }
            return
        } finally {
            if FileExist(tempPath)
                FileDelete(tempPath)
        }
    }
    throw Error("WRITE_CONFLICT|验收期间目标笔记持续变化，未覆盖新内容")
}

WriteResult(message) {
    global resultPath
    try FileDelete(resultPath)
    FileAppend(message "`n", resultPath, "UTF-8-RAW")
}
