#Requires AutoHotkey v2.0

class ImageClipboard {
    static ImageExtensions := "i)^(png|jpe?g|gif|bmp|webp)$"
    static GdiPlusToken := 0

    static DetectImagePath(clipboardText) {
        clipboardText := Trim(FlashNoteCore.NormalizeLineEndings(clipboardText), " `t`n`r")
        if (clipboardText = "")
            return ""

        lines := []
        for rawLine in StrSplit(clipboardText, "`n") {
            line := Trim(rawLine, " `t`r`n" Chr(34))
            if (line != "")
                lines.Push(line)
        }
        if (lines.Length != 1)
            return ""

        path := lines[1]
        if !FileExist(path) || InStr(FileExist(path), "D")
            return ""
        SplitPath(path, , , &extension)
        return RegExMatch(extension, this.ImageExtensions) ? path : ""
    }

    static HasClipboardBitmap() {
        return DllCall("User32\IsClipboardFormatAvailable", "UInt", 2, "Int") != 0
    }

    static HasImage(clipboardText) {
        return this.DetectImagePath(clipboardText) != "" || this.HasClipboardBitmap()
    }

    static ResolveAttachmentFolder(vaultPath) {
        relativeFolder := "assets"
        appConfig := RTrim(vaultPath, "\") "\.obsidian\app.json"
        if FileExist(appConfig) {
            try {
                configText := FlashNoteCore.ReadUtf8File(appConfig)
                if RegExMatch(configText, "i)\x22attachmentFolderPath\x22\s*:\s*\x22([^\x22\\]*(?:\\.[^\x22\\]*)*)\x22", &folderMatch) {
                    configured := folderMatch[1]
                    configured := StrReplace(configured, "\/", "/")
                    configured := StrReplace(configured, "\\", "\")
                    if (configured = "/" || configured = "." || configured = "./")
                        relativeFolder := ""
                    else
                        relativeFolder := Trim(RegExReplace(configured, "^\./", ""), "\/")
                }
            }
        }

        targetFolder := relativeFolder = ""
            ? RTrim(vaultPath, "\")
            : RTrim(vaultPath, "\") "\" StrReplace(relativeFolder, "/", "\")
        if !FlashNoteCore.IsPathInside(targetFolder, vaultPath)
            throw Error("INVALID_ATTACHMENT_FOLDER|Obsidian 附件目录必须位于 Vault 内")
        return {FullPath: targetFolder, RelativePath: StrReplace(relativeFolder, "\", "/")}
    }

    static SaveToVault(vaultPath, clipboardText := "", timestamp := "", randomSuffix := "") {
        if !InStr(FileExist(vaultPath), "D")
            throw Error("VAULT_MISSING|Obsidian Vault 不存在")

        sourcePath := this.DetectImagePath(clipboardText)
        if (sourcePath = "" && !this.HasClipboardBitmap())
            throw Error("EMPTY_IMAGE_CLIPBOARD|剪贴板中没有可保存的图片")

        if (sourcePath != "" && FlashNoteCore.IsPathInside(sourcePath, vaultPath)) {
            fullVault := RTrim(FlashNoteCore.GetFullPath(vaultPath), "\")
            fullSource := FlashNoteCore.GetFullPath(sourcePath)
            relativePath := StrReplace(SubStr(fullSource, StrLen(fullVault) + 2), "\", "/")
            return {FullPath: fullSource, RelativePath: relativePath, Embed: "![[" relativePath "]]", Created: false, SourceKind: "file"}
        }

        attachmentFolder := this.ResolveAttachmentFolder(vaultPath)
        if !InStr(FileExist(attachmentFolder.FullPath), "D")
            DirCreate(attachmentFolder.FullPath)

        timestamp := timestamp != "" ? timestamp : A_Now
        randomSuffix := randomSuffix != "" ? randomSuffix : Format("{:04x}", Random(0, 65535))
        extension := "png"
        if (sourcePath != "") {
            SplitPath(sourcePath, , , &extension)
            extension := StrLower(extension)
        }
        fileName := "大尾巴闪念图片-" FormatTime(timestamp, "yyyyMMdd-HHmmss") "-" randomSuffix "." extension
        targetPath := RTrim(attachmentFolder.FullPath, "\") "\" fileName
        attempt := 0
        while FileExist(targetPath) {
            attempt += 1
            fileName := "大尾巴闪念图片-" FormatTime(timestamp, "yyyyMMdd-HHmmss") "-" randomSuffix "-" attempt "." extension
            targetPath := RTrim(attachmentFolder.FullPath, "\") "\" fileName
        }

        tempPath := FlashNoteCore.MakeTempPath(targetPath)
        try {
            if (sourcePath != "") {
                try FileCopy(sourcePath, tempPath, false)
                catch
                    throw Error("IMAGE_SOURCE_MISSING|图片临时文件已经失效，请重新复制图片后再保存")
            } else {
                this.SaveClipboardBitmapAsPng(tempPath)
            }
            if !FileExist(tempPath) || FileGetSize(tempPath) <= 0
                throw Error("IMAGE_COPY_FAILED|图片附件保存失败")
            FlashNoteCore.AtomicMove(tempPath, targetPath, false)
            tempPath := ""
        } finally {
            if (tempPath != "" && FileExist(tempPath))
                try FileDelete(tempPath)
        }

        relativePath := attachmentFolder.RelativePath = ""
            ? fileName
            : attachmentFolder.RelativePath "/" fileName
        return {FullPath: targetPath, RelativePath: relativePath, Embed: "![[" relativePath "]]", Created: true, SourceKind: sourcePath != "" ? "file" : "bitmap"}
    }

    static SaveClipboardBitmapAsPng(targetPath) {
        bitmapCopy := 0
        gdipBitmap := 0
        this.EnsureGdiPlus()

        try {
            opened := false
            Loop 8 {
                if DllCall("User32\OpenClipboard", "Ptr", A_ScriptHwnd, "Int") {
                    opened := true
                    break
                }
                Sleep(20 * A_Index)
            }
            if !opened
                throw Error("CLIPBOARD_BUSY|剪贴板正被其他程序占用，请重试")
            try {
                bitmapHandle := DllCall("User32\GetClipboardData", "UInt", 2, "Ptr")
                if !bitmapHandle
                    throw Error("EMPTY_IMAGE_CLIPBOARD|剪贴板中没有可保存的位图")
                bitmapCopy := DllCall("User32\CopyImage", "Ptr", bitmapHandle, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x2000, "Ptr")
                if !bitmapCopy
                    throw Error("IMAGE_COPY_FAILED|无法复制剪贴板图片")
            } finally {
                DllCall("User32\CloseClipboard")
            }

            status := DllCall("Gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", bitmapCopy, "Ptr", 0, "Ptr*", &gdipBitmap, "UInt")
            if (status != 0 || !gdipBitmap)
                throw Error("IMAGE_ENCODER_FAILED|无法读取剪贴板图片，状态码：" status)

            pngClsid := Buffer(16, 0)
            if DllCall("Ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", pngClsid, "UInt") != 0
                throw Error("IMAGE_ENCODER_FAILED|无法加载 PNG 编码器")
            status := DllCall("Gdiplus\GdipSaveImageToFile", "Ptr", gdipBitmap, "WStr", targetPath, "Ptr", pngClsid, "Ptr", 0, "UInt")
            if (status != 0)
                throw Error("IMAGE_ENCODER_FAILED|PNG 图片保存失败，状态码：" status)
        } finally {
            if gdipBitmap
                DllCall("Gdiplus\GdipDisposeImage", "Ptr", gdipBitmap)
            if bitmapCopy
                DllCall("Gdi32\DeleteObject", "Ptr", bitmapCopy)
        }
    }

    static EnsureGdiPlus() {
        if this.GdiPlusToken
            return
        startupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, startupInput, 0)
        token := 0
        status := DllCall("Gdiplus\GdiplusStartup", "UPtr*", &token, "Ptr", startupInput, "Ptr", 0, "UInt")
        if (status != 0 || !token)
            throw Error("IMAGE_ENCODER_FAILED|无法启动 Windows 图片编码器，状态码：" status)
        this.GdiPlusToken := token
    }
}
