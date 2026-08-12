#Requires AutoHotkey v2.0

class FlashNoteCore {
    static DefaultAnchor := "<!-- DABAWEI_FLASHNOTE_INBOX -->"
    static DefaultImageWidth := 300

    static NormalizeLineEndings(text) {
        text := StrReplace(text, "`r`n", "`n")
        return StrReplace(text, "`r", "`n")
    }

    static NormalizeFlashText(text) {
        text := Trim(this.NormalizeLineEndings(text), " `t`n")
        if (text = "")
            return ""

        normalized := ""
        blankPending := false
        for rawLine in StrSplit(text, "`n") {
            line := Trim(rawLine, " `t")
            if (line = "") {
                if (normalized != "")
                    blankPending := true
                continue
            }
            line := RegExReplace(line, "\h{2,}", " ")
            if (normalized != "")
                normalized .= blankPending ? "`n`n" : "`n"
            normalized .= line
            blankPending := false
        }
        return normalized
    }

    static FormatListContent(content, isTodo := false, sourceLabel := "") {
        lines := StrSplit(content, "`n")
        if (!isTodo && sourceLabel != "") {
            formatted := "- " sourceLabel " #闪念"
            for line in lines {
                if (line = "") {
                    formatted := RTrim(formatted, " ") "`n"
                    continue
                }
                formatted .= "`n  " line "  "
            }
            return formatted
        }
        prefix := isTodo ? "- [ ] " : "- "
        tags := isTodo ? " #闪念 #待办" : " #闪念"
        formatted := prefix lines[1] tags "  "

        Loop lines.Length - 1 {
            line := lines[A_Index + 1]
            if (line = "") {
                formatted := RTrim(formatted, " ") "`n"
                continue
            }
            formatted .= "`n  " line "  "
        }
        return formatted
    }

    static FormatCodeBlockListContent(content, isTodo := false) {
        prefix := isTodo ? "- [ ] #闪念 #待办" : "- #闪念"
        fenced := ClipboardFormatter.BuildCodeFence(content)
        indented := ""
        for line in StrSplit(fenced, "`n")
            indented .= (indented = "" ? "" : "`n") "  " line
        return prefix "`n`n" indented
    }

    static IsHttpUrl(url) {
        return RegExMatch(Trim(url), "i)^https?://[^\s]+$") = 1
    }

    static SourceClipSentence(url) {
        url := Trim(url)
        if (url = "")
            return ""
        if !this.IsHttpUrl(url)
            throw Error("INVALID_SOURCE_URL|来源网址必须以 http:// 或 https:// 开头")
        if !RegExMatch(url, "i)^https?://(?:www\.)?([^/:?#]+)", &hostMatch)
            throw Error("INVALID_SOURCE_URL|无法识别来源网址的域名")
        return "来自" StrLower(hostMatch[1]) "网页的剪藏。"
    }

    static BuildFlashBlock(text, sourceUrl := "", isTodo := false, timestamp := "", randomSuffix := "", contentFormat := "plain_text") {
        content := this.NormalizeFlashText(text)
        if (content = "")
            throw Error("EMPTY_CLIPBOARD|剪贴板没有可保存的文字")

        timestamp := timestamp != "" ? timestamp : A_Now
        randomSuffix := randomSuffix != "" ? randomSuffix : Format("{:04x}", Random(0, 65535))
        titleStamp := FormatTime(timestamp, "yyyyMMddHHmm")
        dateStamp := FormatTime(timestamp, "yyyy-MM-dd HH:mm")
        secondStamp := FormatTime(timestamp, "yyyyMMddHHmmss")
        blockId := "flash-" FormatTime(timestamp, "yyyyMMdd-HHmmss") "-pc"
        standaloneCodeBlock := contentFormat = "code_block" && !isTodo
        sourceLabel := !isTodo ? this.SourceClipSentence(sourceUrl) : ""

        block := "**大尾巴闪念-" titleStamp "**`n"
        block .= (standaloneCodeBlock
            ? (sourceLabel != "" ? sourceLabel " #闪念" : "#闪念") "`n`n" ClipboardFormatter.BuildCodeFence(text)
            : contentFormat = "code_block"
                ? this.FormatCodeBlockListContent(text, isTodo)
                : this.FormatListContent(content, isTodo, sourceLabel)) "`n"
        metadataIndent := standaloneCodeBlock ? "" : "  "
        block .= metadataIndent "记录日期:: " dateStamp "`n"
        if isTodo {
            block .= metadataIndent "任务ID:: pc-" secondStamp "-" randomSuffix "`n"
            block .= metadataIndent "截止日期::`n"
            block .= metadataIndent "提醒时间::`n"
        }
        if (sourceUrl != "") {
            if !this.IsHttpUrl(sourceUrl)
                throw Error("INVALID_SOURCE_URL|来源网址必须以 http:// 或 https:// 开头")
            block .= metadataIndent "来源网址:: " Trim(sourceUrl) "`n"
        }
        block .= metadataIndent "备注::`n"
        block .= metadataIndent "^" blockId

        return {
            Text: block,
            BlockId: blockId,
            TaskId: isTodo ? "pc-" secondStamp "-" randomSuffix : ""
        }
    }

    static BuildImageEmbed(imageRelativePath) {
        imageRelativePath := Trim(StrReplace(imageRelativePath, "\", "/"), " /")
        if (imageRelativePath = "" || InStr(imageRelativePath, "]]"))
            throw Error("INVALID_IMAGE_PATH|图片附件路径无效")
        return "![[" imageRelativePath "|" this.DefaultImageWidth "]]"
    }

    static BuildImageFlashBlock(imageRelativePath, sourceUrl := "", isTodo := false, timestamp := "", randomSuffix := "") {
        embed := this.BuildImageEmbed(imageRelativePath)

        timestamp := timestamp != "" ? timestamp : A_Now
        randomSuffix := randomSuffix != "" ? randomSuffix : Format("{:04x}", Random(0, 65535))
        titleStamp := FormatTime(timestamp, "yyyyMMddHHmm")
        dateStamp := FormatTime(timestamp, "yyyy-MM-dd HH:mm")
        secondStamp := FormatTime(timestamp, "yyyyMMddHHmmss")
        blockId := "flash-image-" FormatTime(timestamp, "yyyyMMdd-HHmmss") "-pc"
        sourceLabel := !isTodo ? this.SourceClipSentence(sourceUrl) : ""
        block := "**大尾巴闪念-" titleStamp "**`n"
        if isTodo {
            block .= "- [ ] 图片剪藏 #闪念 #待办  `n"
            block .= "  " embed "`n"
            metadataIndent := "  "
        } else {
            block .= (sourceLabel != "" ? sourceLabel " #闪念" : "#闪念") "`n`n"
            block .= embed "`n"
            metadataIndent := ""
        }
        block .= metadataIndent "记录日期:: " dateStamp "`n"
        if isTodo {
            block .= metadataIndent "任务ID:: pc-" secondStamp "-" randomSuffix "`n"
            block .= metadataIndent "截止日期::`n"
            block .= metadataIndent "提醒时间::`n"
        }
        if (sourceUrl != "") {
            if !this.IsHttpUrl(sourceUrl)
                throw Error("INVALID_SOURCE_URL|来源网址必须以 http:// 或 https:// 开头")
            block .= metadataIndent "来源网址:: " Trim(sourceUrl) "`n"
        }
        block .= metadataIndent "备注::`n"
        block .= metadataIndent "^" blockId

        return {
            Text: block,
            BlockId: blockId,
            TaskId: isTodo ? "pc-" secondStamp "-" randomSuffix : ""
        }
    }

    static CountOccurrences(haystack, needle) {
        if (needle = "")
            return 0
        count := 0
        position := 1
        while found := InStr(haystack, needle, true, position) {
            count += 1
            position := found + StrLen(needle)
        }
        return count
    }

    static DetectLineBreak(text) {
        return InStr(text, "`r`n") ? "`r`n" : "`n"
    }

    static InsertBelowAnchor(markdown, anchor, block) {
        anchor := Trim(anchor) != "" ? Trim(anchor) : this.DefaultAnchor
        count := this.CountOccurrences(markdown, anchor)
        if (count != 1)
            throw Error("ANCHOR_COUNT|闪念锚点数量必须为 1，当前为 " count)

        eol := this.DetectLineBreak(markdown)
        anchorStart := InStr(markdown, anchor, true)
        afterAnchor := anchorStart + StrLen(anchor)
        prefixEnd := afterAnchor - 1

        if (SubStr(markdown, afterAnchor, 2) = "`r`n")
            prefixEnd := afterAnchor + 1
        else if (SubStr(markdown, afterAnchor, 1) = "`n" || SubStr(markdown, afterAnchor, 1) = "`r")
            prefixEnd := afterAnchor
        else
            prefixEnd := afterAnchor - 1

        prefix := SubStr(markdown, 1, prefixEnd)
        if (prefixEnd = afterAnchor - 1)
            prefix .= eol
        suffix := SubStr(markdown, prefixEnd + 1)
        while (SubStr(suffix, 1, StrLen(eol)) = eol)
            suffix := SubStr(suffix, StrLen(eol) + 1)

        return prefix RTrim(this.NormalizeLineEndings(block), "`r`n") eol eol suffix
    }

    static ReadUtf8File(path) {
        if !FileExist(path)
            throw Error("TARGET_MISSING|找不到目标文件：" path)

        raw := FileRead(path, "RAW")
        if (raw.Size >= 2) {
            first := NumGet(raw, 0, "UChar")
            second := NumGet(raw, 1, "UChar")
            if ((first = 0xFF && second = 0xFE) || (first = 0xFE && second = 0xFF))
                throw Error("UNSUPPORTED_ENCODING|目标文件必须是 UTF-8 编码")
        }
        return FileRead(path, "UTF-8")
    }

    static HasUtf8Bom(path) {
        raw := FileRead(path, "RAW")
        return raw.Size >= 3
            && NumGet(raw, 0, "UChar") = 0xEF
            && NumGet(raw, 1, "UChar") = 0xBB
            && NumGet(raw, 2, "UChar") = 0xBF
    }

    static WriteUtf8File(path, content, withBom := false) {
        encoding := withBom ? "UTF-8" : "UTF-8-RAW"
        file := FileOpen(path, "w", encoding)
        try file.Write(content)
        finally file.Close()
    }

    static MakeTempPath(targetPath) {
        return targetPath ".dabawei-" DllCall("Kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount "-" Random(1000, 9999) ".tmp"
    }

    static AtomicMove(tempPath, targetPath, replaceExisting := true) {
        flags := 0x8 | (replaceExisting ? 0x1 : 0)
        lastError := 0
        Loop 8 {
            if DllCall("Kernel32\MoveFileExW", "Str", tempPath, "Str", targetPath, "UInt", flags, "Int")
                return true
            lastError := A_LastError
            if !(lastError = 5 || lastError = 32 || lastError = 33)
                break
            Sleep(20 * A_Index)
        }
        throw Error("ATOMIC_MOVE_FAILED|安全替换失败，Windows 错误码：" lastError)
    }

    static SafeInsertFile(path, anchor, block, uniqueId) {
        Loop 2 {
            tempPath := ""
            original := this.ReadUtf8File(path)
            withBom := this.HasUtf8Bom(path)
            updated := this.InsertBelowAnchor(original, anchor, block)
            tempPath := this.MakeTempPath(path)
            try {
                this.WriteUtf8File(tempPath, updated, withBom)
                current := this.ReadUtf8File(path)
                if (current != original) {
                    try FileDelete(tempPath)
                    tempPath := ""
                    if (A_Index = 2)
                        throw Error("CONCURRENT_CHANGE|目标笔记刚刚发生变化，请再试一次")
                    continue
                }
                this.AtomicMove(tempPath, path, true)
                tempPath := ""
                verified := this.ReadUtf8File(path)
                if !InStr(verified, uniqueId, true)
                    throw Error("VERIFY_FAILED|写入后验证失败")
                return true
            } finally {
                if (tempPath != "" && FileExist(tempPath)) {
                    try FileDelete(tempPath)
                }
            }
        }
        throw Error("CONCURRENT_CHANGE|目标笔记刚刚发生变化，请再试一次")
    }

    static SanitizeTitle(title, maxLength := 40) {
        title := Trim(this.NormalizeLineEndings(title))
        title := RegExReplace(title, "\n.*$", "")
        invalidPattern := "[<>:/\\|?*\x00-\x1F" Chr(34) "]"
        title := RegExReplace(title, invalidPattern, " ")
        title := RegExReplace(title, "\h{2,}", " ")
        title := Trim(title, " .`t`r`n")
        if RegExMatch(title, "i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$")
            title := "笔记-" title
        if (StrLen(title) > maxLength)
            title := SubStr(title, 1, maxLength)
        return Trim(title, " .")
    }

    static SuggestTitle(text, timestamp := "") {
        title := this.SanitizeTitle(text)
        if (title != "")
            return title
        timestamp := timestamp != "" ? timestamp : A_Now
        return FormatTime(timestamp, "yyyyMMdd-HHmmss") "-新笔记"
    }

    static GetFullPath(path) {
        pathBuffer := Buffer(65536, 0)
        length := DllCall("Kernel32\GetFullPathNameW", "Str", path, "UInt", 32768, "Ptr", pathBuffer, "Ptr", 0, "UInt")
        if (length = 0 || length >= 32768)
            throw Error("INVALID_PATH|无法解析路径：" path)
        return StrGet(pathBuffer, length, "UTF-16")
    }

    static IsPathInside(path, root) {
        fullPath := StrLower(RTrim(this.GetFullPath(path), "\"))
        fullRoot := StrLower(RTrim(this.GetFullPath(root), "\"))
        return fullPath = fullRoot || InStr(fullPath, fullRoot "\", true) = 1
    }

    static YamlQuote(value) {
        value := StrReplace(value, "\", "\\")
        value := StrReplace(value, Chr(34), "\" Chr(34))
        return Chr(34) value Chr(34)
    }

    static BuildNewNote(title, body, sourceUrl := "", timestamp := "") {
        cleanTitle := this.SanitizeTitle(title)
        if (cleanTitle = "")
            throw Error("EMPTY_TITLE|标题不能为空")
        if (sourceUrl != "" && !this.IsHttpUrl(sourceUrl))
            throw Error("INVALID_SOURCE_URL|来源网址必须以 http:// 或 https:// 开头")

        timestamp := timestamp != "" ? timestamp : A_Now
        note := "---`n"
        note .= "创建日期: " FormatTime(timestamp, "yyyy-MM-dd HH:mm") "`n"
        if (sourceUrl != "")
            note .= "来源网址: " this.YamlQuote(Trim(sourceUrl)) "`n"
        note .= "tags:`n  - 闪念`n---`n`n"
        note .= "# " cleanTitle "`n"
        body := Trim(this.NormalizeLineEndings(body))
        if (body != "")
            note .= "`n" body "`n"
        return {Text: note, Title: cleanTitle}
    }

    static BuildNewNoteLinkBlock(vaultPath, notePath, sourceUrl := "", timestamp := "") {
        if !this.IsPathInside(notePath, vaultPath)
            throw Error("OUTSIDE_VAULT|新建笔记必须位于 Obsidian Vault 内")

        fullVault := RTrim(this.GetFullPath(vaultPath), "\")
        fullNote := this.GetFullPath(notePath)
        relativePath := SubStr(fullNote, StrLen(fullVault) + 2)
        relativePath := RegExReplace(relativePath, "i)\.md$", "")
        relativePath := StrReplace(relativePath, "\", "/")
        SplitPath(fullNote, , , , &displayTitle)

        timestamp := timestamp != "" ? timestamp : A_Now
        titleStamp := FormatTime(timestamp, "yyyyMMddHHmm")
        dateStamp := FormatTime(timestamp, "yyyy-MM-dd HH:mm")
        blockId := "flash-link-" FormatTime(timestamp, "yyyyMMdd-HHmmss") "-pc"
        sourceLabel := this.SourceClipSentence(sourceUrl)

        block := "**大尾巴闪念-" titleStamp "**`n"
        block .= "- 新建笔记：[[" relativePath "|" displayTitle "]] #闪念  `n"
        if (sourceLabel != "")
            block .= "  " sourceLabel "  `n"
        block .= "  记录日期:: " dateStamp "`n"
        if (sourceUrl != "")
            block .= "  来源网址:: " Trim(sourceUrl) "`n"
        block .= "  备注::`n"
        block .= "  ^" blockId
        return {Text: block, BlockId: blockId}
    }

    static CreateNewNote(vaultPath, folderPath, title, body, sourceUrl := "", timestamp := "") {
        if !InStr(FileExist(folderPath), "D")
            throw Error("NEW_NOTE_FOLDER_MISSING|新建笔记目录不存在")
        if !this.IsPathInside(folderPath, vaultPath)
            throw Error("OUTSIDE_VAULT|新建笔记目录必须位于 Obsidian Vault 内")

        timestamp := timestamp != "" ? timestamp : A_Now
        built := this.BuildNewNote(title, body, sourceUrl, timestamp)
        basePath := RTrim(folderPath, "\") "\" built.Title
        targetPath := basePath ".md"
        if FileExist(targetPath)
            targetPath := basePath "-" FormatTime(timestamp, "yyyyMMdd-HHmmss") ".md"

        attempt := 0
        while FileExist(targetPath) {
            attempt += 1
            targetPath := basePath "-" FormatTime(timestamp, "yyyyMMdd-HHmmss") "-" attempt ".md"
        }

        tempPath := this.MakeTempPath(targetPath)
        try {
            this.WriteUtf8File(tempPath, built.Text, false)
            this.AtomicMove(tempPath, targetPath, false)
            tempPath := ""
            return targetPath
        } finally {
            if (tempPath != "" && FileExist(tempPath)) {
                try FileDelete(tempPath)
            }
        }
    }
}
