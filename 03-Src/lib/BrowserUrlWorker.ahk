#Requires AutoHotkey v2.0
#SingleInstance Off

#Include "BrowserSource.ahk"

if (A_Args.Length < 2)
    ExitApp(2)

browserHwnd := Integer(A_Args[1])
outputPath := A_Args[2]
url := ""
try url := BrowserSource.ReadBrowserUrlUIARaw(browserHwnd)
try FileDelete(outputPath)
FileAppend(url, outputPath, "UTF-8-RAW")
ExitApp(0)
