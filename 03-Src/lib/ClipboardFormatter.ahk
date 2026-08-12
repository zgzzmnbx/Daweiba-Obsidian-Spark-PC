#Requires AutoHotkey v2.0

class ClipboardFormatter {
    static SmartMarkdown := "smart_markdown"
    static CodeBlock := "code_block"
    static PlainText := "plain_text"

    static IsValidMode(mode) {
        return mode = this.SmartMarkdown || mode = this.CodeBlock || mode = this.PlainText
    }

    static PrepareFlashText(plainText, cfHtml, mode) {
        if !this.IsValidMode(mode)
            throw Error("INVALID_CONTENT_FORMAT|内容格式配置无效")
        if ((mode = this.SmartMarkdown || mode = this.CodeBlock) && Trim(cfHtml) != "") {
            markdown := this.HtmlToMarkdown(cfHtml)
            if (Trim(markdown) != "")
                return markdown
        }
        return plainText
    }

    static PrepareStandalone(plainText, cfHtml, mode) {
        content := this.PrepareFlashText(plainText, cfHtml, mode)
        return mode = this.CodeBlock ? this.BuildCodeFence(content) : content
    }

    static HtmlToMarkdown(cfHtml) {
        html := this.ExtractFragment(cfHtml)
        if (Trim(html) = "")
            return ""

        html := RegExReplace(html, "is)<(script|style|noscript|svg)\b[^>]*>.*?</\1>", "")
        html := RegExReplace(html, "is)<!--.*?-->", "")
        html := this.ConvertInlineStyleBold(html)
        html := RegExReplace(html, "is)<(?:strong|b)\b[^>]*>", "**")
        html := RegExReplace(html, "is)</(?:strong|b)\s*>", "**")
        html := RegExReplace(html, "is)<(?:em|i)\b[^>]*>", "*")
        html := RegExReplace(html, "is)</(?:em|i)\s*>", "*")
        html := RegExReplace(html, "is)<br\b[^>]*>", "`n")
        html := RegExReplace(html, "is)<li\b[^>]*>", "`n- ")
        html := RegExReplace(html, "is)</li\s*>", "`n")
        html := RegExReplace(html, "is)</(?:p|div|section|article|header|footer|h[1-6]|blockquote|pre|ul|ol)\s*>", "`n`n")
        html := RegExReplace(html, "is)<(?:p|div|section|article|header|footer|h[1-6]|blockquote|pre|ul|ol)\b[^>]*>", "")
        html := RegExReplace(html, "is)<[^>]+>", "")
        html := this.DecodeEntities(html)
        html := RegExReplace(html, "\*\*\h+", "**")
        html := RegExReplace(html, "\h+\*\*", "**")
        return this.NormalizeMarkdown(html)
    }

    static ConvertInlineStyleBold(html) {
        patterns := [
            "is)<(span|div|p)\b[^>]*style\s*=\s*" Chr(34) "[^" Chr(34) "]*font-weight\s*:\s*(?:bold|[6-9]00)[^" Chr(34) "]*" Chr(34) "[^>]*>(.*?)</\1\s*>",
            "is)<(span|div|p)\b[^>]*style\s*=\s*'[^']*font-weight\s*:\s*(?:bold|[6-9]00)[^']*'[^>]*>(.*?)</\1\s*>"
        ]
        for pattern in patterns {
            Loop 5 {
                replaceCount := 0
                html := RegExReplace(html, pattern, "**$2**", &replaceCount)
                if (replaceCount = 0)
                    break
            }
        }
        return html
    }

    static ExtractFragment(cfHtml) {
        if RegExMatch(cfHtml, "is)<!--StartFragment-->(.*?)<!--EndFragment-->", &fragment)
            return fragment[1]
        if RegExMatch(cfHtml, "is)(<html\b.*)", &document)
            return document[1]
        return cfHtml
    }

    static DecodeEntities(text) {
        replacements := Map(
            "&nbsp;", " ",
            "&amp;", "&",
            "&lt;", "<",
            "&gt;", ">",
            "&quot;", Chr(34),
            "&apos;", "'",
            "&#39;", "'"
        )
        for entity, value in replacements
            text := StrReplace(text, entity, value, true)
        text := this.DecodeNumericEntities(text, "i)&#x([0-9a-f]+);", 16)
        return this.DecodeNumericEntities(text, "&#([0-9]+);", 10)
    }

    static DecodeNumericEntities(text, pattern, base) {
        position := 1
        while found := RegExMatch(text, pattern, &match, position) {
            try codePoint := base = 16 ? Integer("0x" match[1]) : Integer(match[1])
            catch {
                position := found + StrLen(match[0])
                continue
            }
            replacement := Chr(codePoint)
            text := SubStr(text, 1, found - 1) replacement SubStr(text, found + StrLen(match[0]))
            position := found + StrLen(replacement)
        }
        return text
    }

    static NormalizeMarkdown(text) {
        text := FlashNoteCore.NormalizeLineEndings(text)
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

    static BuildCodeFence(text, language := "markdown") {
        text := Trim(FlashNoteCore.NormalizeLineEndings(text), "`n")
        maxRun := 0
        currentRun := 0
        for char in StrSplit(text) {
            if (char = Chr(96)) {
                currentRun += 1
                maxRun := Max(maxRun, currentRun)
            } else {
                currentRun := 0
            }
        }
        fence := ""
        Loop Max(3, maxRun + 1)
            fence .= Chr(96)
        return fence language "`n" text "`n" fence
    }
}
