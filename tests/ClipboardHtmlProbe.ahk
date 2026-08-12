#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\03-Src\lib\FlashNoteCore.ahk"
#Include "..\03-Src\lib\ClipboardFormatter.ahk"
#Include "..\03-Src\lib\BrowserSource.ahk"

if (A_Args.Length < 1)
    ExitApp(2)

resultPath := A_Args[1]
html := BrowserSource.ReadClipboardHtml()
markdown := ClipboardFormatter.HtmlToMarkdown(html)
result := "HTML_LENGTH=" StrLen(html) "`n"
    . "HAS_STRONG_OR_B=" (RegExMatch(html, "i)<(?:strong|b)\b") ? 1 : 0) "`n"
    . "HAS_FONT_WEIGHT=" (RegExMatch(html, "i)font-weight\s*:") ? 1 : 0) "`n"
    . "MARKDOWN_HAS_BOLD=" (InStr(markdown, "**") ? 1 : 0) "`n"
try FileDelete(resultPath)
FileAppend(result, resultPath, "UTF-8-RAW")
ExitApp(0)
