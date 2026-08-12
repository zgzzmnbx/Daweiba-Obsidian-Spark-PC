#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\03-Src\lib\FlashNoteCore.ahk"
#Include "..\03-Src\lib\ClipboardFormatter.ahk"
#Include "..\03-Src\lib\ConfigStore.ahk"
#Include "..\03-Src\lib\BrowserSource.ahk"

global Passed := 0
global Failed := 0
global ResultPath := A_ScriptDir "\..\Codex-Temp\core-tests\test-results.txt"
global FailureMessages := ""

AssertEqual(expected, actual, label) {
    global Passed, Failed, FailureMessages
    if (expected = actual) {
        Passed += 1
        return
    }
    Failed += 1
    FailureMessages .= "FAIL " label "`nExpected: " expected "`nActual: " actual "`n`n"
}

AssertTrue(value, label) {
    AssertEqual(true, !!value, label)
}

AssertThrows(callback, expectedCode, label) {
    global Passed, Failed, FailureMessages
    try callback.Call()
    catch as err {
        if InStr(err.Message, expectedCode "|", true) = 1 {
            Passed += 1
            return
        }
        Failed += 1
        FailureMessages .= "FAIL " label "`nUnexpected error: " err.Message "`n`n"
        return
    }
    Failed += 1
    FailureMessages .= "FAIL " label "`nExpected exception: " expectedCode "`n`n"
}

try {
testRoot := A_ScriptDir "\..\Codex-Temp\core-tests"
if InStr(FileExist(testRoot), "D")
    DirDelete(testRoot, true)
DirCreate(testRoot)

normal := FlashNoteCore.BuildFlashBlock(
    "第一行`r`n第二行`r`n`r`n第三段`r`n第四行",
    "https://example.com/a?b=1",
    false,
    "20260812153045",
    "a1b2"
)
AssertTrue(InStr(normal.Text, "**大尾巴闪念-202608121530**"), "normal title")
AssertTrue(InStr(normal.Text, "- 第一行 #闪念  `n  第二行`n`n  第三段  `n  第四行  `n"), "normal paragraphs")
AssertTrue(!InStr(normal.Text, " / "), "normal does not flatten newlines")
AssertTrue(InStr(normal.Text, "来源网址:: https://example.com/a?b=1"), "normal source url")
AssertEqual("flash-20260812-153045-pc", normal.BlockId, "normal block id")

todo := FlashNoteCore.BuildFlashBlock("处理合同", "", true, "20260812153100", "c3d4")
AssertTrue(InStr(todo.Text, "- [ ] 处理合同 #闪念 #待办"), "todo line")
AssertTrue(InStr(todo.Text, "任务ID:: pc-20260812153100-c3d4"), "todo id")
AssertTrue(InStr(todo.Text, "截止日期::`n  提醒时间::"), "todo empty dates")

multilineTodo := FlashNoteCore.BuildFlashBlock("主任务`n补充说明`n`n第二段", "", true, "20260812153101", "d4e5")
AssertTrue(InStr(multilineTodo.Text, "- [ ] 主任务 #闪念 #待办  `n  补充说明`n`n  第二段  `n"), "todo paragraphs")

richHtml := "Version:1.0`r`nSourceURL:https://example.com/rich`r`n<!--StartFragment--><p><strong>Codex 这句加粗</strong><br>普通文字</p><p>第二段 &amp; 符号</p><!--EndFragment-->"
richMarkdown := ClipboardFormatter.HtmlToMarkdown(richHtml)
AssertTrue(InStr(richMarkdown, "**Codex 这句加粗**"), "html strong to markdown bold")
AssertTrue(InStr(richMarkdown, "普通文字`n`n第二段 & 符号"), "html paragraphs and entities")
smartFlash := FlashNoteCore.BuildFlashBlock(richMarkdown, "https://example.com/rich", false, "20260812153102", "e5f6", ClipboardFormatter.SmartMarkdown)
AssertTrue(InStr(smartFlash.Text, "- **Codex 这句加粗** #闪念"), "smart markdown bold in flash")

fence3 := Chr(96) Chr(96) Chr(96)
fence4 := fence3 Chr(96)
fenced := ClipboardFormatter.BuildCodeFence("line 1`n" fence3 "nested" fence3)
AssertTrue(InStr(fenced, fence4 "markdown`nline 1`n" fence3 "nested" fence3 "`n" fence4), "code fence expands for nested backticks")
codeFlash := FlashNoteCore.BuildFlashBlock("**保留为源码**`n第二行", "", false, "20260812153103", "f607", ClipboardFormatter.CodeBlock)
AssertTrue(InStr(codeFlash.Text, "- #闪念`n`n  " fence3 "markdown`n  **保留为源码**`n  第二行`n  " fence3), "flash markdown code block")
standaloneCode := ClipboardFormatter.PrepareStandalone("原样内容", "", ClipboardFormatter.CodeBlock)
AssertEqual(fence3 "markdown`n原样内容`n" fence3, standaloneCode, "standalone markdown code block")
richCodeInput := ClipboardFormatter.PrepareFlashText("纯文本兜底", richHtml, ClipboardFormatter.CodeBlock)
richCodeFlash := FlashNoteCore.BuildFlashBlock(richCodeInput, "", false, "20260812153104", "0718", ClipboardFormatter.CodeBlock)
AssertTrue(InStr(richCodeFlash.Text, fence3 "markdown`n  **Codex 这句加粗**"), "code block keeps recognized bold markdown source")
styledBoldHtml := "<!--StartFragment--><div><span style=" Chr(34) "font-weight: 700; color: rgb(255,255,255)" Chr(34) ">Codex 这个用法一定要改，结果会好一个量级</span></div><!--EndFragment-->"
styledBoldMarkdown := ClipboardFormatter.HtmlToMarkdown(styledBoldHtml)
AssertEqual("**Codex 这个用法一定要改，结果会好一个量级**", styledBoldMarkdown, "inline font weight to markdown bold")
styledBoldCode := ClipboardFormatter.PrepareStandalone("纯文本", styledBoldHtml, ClipboardFormatter.CodeBlock)
AssertTrue(InStr(styledBoldCode, fence3 "markdown`n**Codex 这个用法一定要改，结果会好一个量级**`n" fence3), "styled bold inside markdown code block")

source := "# Inbox`n`n<!-- DABAWEI_FLASHNOTE_INBOX -->`n`n- old`n"
inserted := FlashNoteCore.InsertBelowAnchor(source, FlashNoteCore.DefaultAnchor, normal.Text)
AssertTrue(InStr(inserted, "<!-- DABAWEI_FLASHNOTE_INBOX -->`n**大尾巴闪念-202608121530**"), "insert below anchor")
AssertTrue(InStr(inserted, "^flash-20260812-153045-pc`n`n- old"), "preserve old content")
AssertThrows(() => FlashNoteCore.InsertBelowAnchor("# no anchor", FlashNoteCore.DefaultAnchor, "x"), "ANCHOR_COUNT", "missing anchor")
AssertThrows(() => FlashNoteCore.InsertBelowAnchor(FlashNoteCore.DefaultAnchor "`n" FlashNoteCore.DefaultAnchor, FlashNoteCore.DefaultAnchor, "x"), "ANCHOR_COUNT", "duplicate anchor")
customAnchor := "<!-- CUSTOM_FLASHNOTE_INBOX -->"
customInserted := FlashNoteCore.InsertBelowAnchor("# Custom`n`n" customAnchor "`n", customAnchor, "custom block")
AssertTrue(InStr(customInserted, customAnchor "`ncustom block"), "custom configured anchor insert")

cfHtml := "Version:1.0`r`nStartHTML:000000010`r`nSourceURL:https://example.org/page`r`n<html></html>"
AssertEqual("https://example.org/page", BrowserSource.ParseSourceUrl(cfHtml), "parse source url")
AssertEqual("", BrowserSource.ParseSourceUrl("<html></html>"), "missing source url")

fixture := testRoot "\fixture.md"
FlashNoteCore.WriteUtf8File(fixture, source, false)
FlashNoteCore.SafeInsertFile(fixture, FlashNoteCore.DefaultAnchor, normal.Text, normal.BlockId)
saved := FlashNoteCore.ReadUtf8File(fixture)
AssertTrue(InStr(saved, normal.BlockId), "safe file insert")
AssertTrue(!FlashNoteCore.HasUtf8Bom(fixture), "utf8 raw preserved")

noteFolder := testRoot "\notes"
try DirCreate(noteFolder)
notePath := FlashNoteCore.CreateNewNote(testRoot, noteFolder, "测试：标题", "正文`n第二行", "https://example.com", "20260812153200")
AssertTrue(FileExist(notePath), "new note created")
noteText := FlashNoteCore.ReadUtf8File(notePath)
AssertTrue(InStr(noteText, "# 测试：标题"), "new note title sanitized")
AssertTrue(InStr(noteText, "来源网址: " Chr(34) "https://example.com" Chr(34)), "new note source")
secondPath := FlashNoteCore.CreateNewNote(testRoot, noteFolder, "测试：标题", "正文", "", "20260812153200")
AssertTrue(notePath != secondPath && FileExist(secondPath), "new note no overwrite")
AssertThrows(() => FlashNoteCore.CreateNewNote(noteFolder, testRoot, "越界", "", "", "20260812153300"), "OUTSIDE_VAULT", "reject outside vault")

configPath := testRoot "\unicode-config.ini"
configFixture := {
    Vault: "C:\OBS\Damon",
    FlashNote: "C:\OBS\Damon\【MOC】闪念-随手记.md",
    NewNoteFolder: "C:\OBS\Damon\01-看板-日记-杂项",
    Anchor: "<!-- CUSTOM_FLASHNOTE_INBOX -->",
    NormalHotkey: "^!s",
    TodoHotkey: "^!t",
    NewNoteHotkey: "^!n",
    SourceUrlEnabled: 1,
    BrowserFallback: 1,
    AddressBarCopyFallback: 1,
    ContentFormat: ClipboardFormatter.SmartMarkdown,
    StartWithWindows: 0
}
ConfigStore.Write(configPath, configFixture)
configValues := ConfigStore.Read(configPath)
AssertEqual(configFixture.FlashNote, ConfigStore.Get(configValues, "Paths", "FlashNote"), "unicode config flash path")
AssertEqual(configFixture.NewNoteFolder, ConfigStore.Get(configValues, "Paths", "NewNoteFolder"), "unicode config note folder")
AssertEqual(configFixture.Anchor, ConfigStore.Get(configValues, "Write", "Anchor"), "config custom anchor")
AssertEqual("^!n", ConfigStore.Get(configValues, "Hotkeys", "NewNote"), "config hotkey")
AssertEqual(ClipboardFormatter.SmartMarkdown, ConfigStore.Get(configValues, "Content", "Format"), "config content format")
AssertTrue(!FlashNoteCore.HasUtf8Bom(configPath), "config utf8 raw")

try FileDelete(ResultPath)
FileAppend("PASS=" Passed " FAIL=" Failed "`n" FailureMessages, ResultPath, "UTF-8-RAW")
ExitApp(Failed = 0 ? 0 : 1)
} catch as fatalError {
    try DirCreate(A_ScriptDir "\..\Codex-Temp\core-tests")
    try FileDelete(ResultPath)
    FileAppend("FATAL=" fatalError.Message "`nWHAT=" fatalError.What "`nLINE=" fatalError.Line "`n", ResultPath, "UTF-8-RAW")
    ExitApp(2)
}
