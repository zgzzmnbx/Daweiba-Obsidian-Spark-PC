#Requires AutoHotkey v2.0

class ConfigStore {
    static Read(path) {
        if !FileExist(path)
            return Map()
        return this.Parse(FlashNoteCore.ReadUtf8File(path))
    }

    static Parse(text) {
        values := Map()
        section := ""
        for rawLine in StrSplit(text, "`n", "`r") {
            line := Trim(rawLine)
            if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
                continue
            if RegExMatch(line, "^\[(.+)\]$", &sectionMatch) {
                section := Trim(sectionMatch[1])
                continue
            }
            separator := InStr(line, "=")
            if (section = "" || separator <= 1)
                continue
            key := Trim(SubStr(line, 1, separator - 1))
            value := Trim(SubStr(line, separator + 1))
            values[section "." key] := value
        }
        return values
    }

    static Get(values, section, key, defaultValue := "") {
        compositeKey := section "." key
        return values.Has(compositeKey) ? values[compositeKey] : defaultValue
    }

    static Write(path, config) {
        text := "[Paths]`n"
            . "Vault=" config.Vault "`n"
            . "FlashNote=" config.FlashNote "`n"
            . "NewNoteFolder=" config.NewNoteFolder "`n`n"
            . "[Write]`n"
            . "Anchor=" config.Anchor "`n`n"
            . "[Hotkeys]`n"
            . "Normal=" config.NormalHotkey "`n"
            . "Todo=" config.TodoHotkey "`n"
            . "NewNote=" config.NewNoteHotkey "`n`n"
            . "[SourceUrl]`n"
            . "Enabled=" config.SourceUrlEnabled "`n"
            . "BrowserFallback=" config.BrowserFallback "`n"
            . "AddressBarCopyFallback=" config.AddressBarCopyFallback "`n`n"
            . "[Content]`n"
            . "Format=" config.ContentFormat "`n`n"
            . "[Startup]`n"
            . "StartWithWindows=" config.StartWithWindows "`n"
        tempPath := FlashNoteCore.MakeTempPath(path)
        try {
            FlashNoteCore.WriteUtf8File(tempPath, text, false)
            FlashNoteCore.AtomicMove(tempPath, path, true)
        } finally {
            if FileExist(tempPath)
                FileDelete(tempPath)
        }
    }
}
