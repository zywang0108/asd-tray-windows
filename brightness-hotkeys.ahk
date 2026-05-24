#Requires AutoHotkey v2.0
#SingleInstance Force

ASDBCTL := "C:\Users\Admin\Tools\asdbctl\target\release\asdbctl.exe"
UI_SCRIPT := "C:\Users\Admin\Tools\asdbctl\brightness-ui.ps1"
StepSize := 5

RunSilent(cmd) {
    RunWait(A_ComSpec ' /c ' cmd, , "Hide")
}

RunSilentCapture(cmd) {
    tmp := A_Temp "\asdbctl_out.txt"
    RunWait(A_ComSpec ' /c ' cmd ' > "' tmp '" 2>&1', , "Hide")
    out := FileExist(tmp) ? FileRead(tmp) : ""
    try FileDelete(tmp)
    return out
}

BumpBrightness(direction) {
    global ASDBCTL, StepSize
    cmd := direction = "up" ? "up" : "down"
    RunSilent(Format('"{1}" {2} -s {3}', ASDBCTL, cmd, StepSize))
}

GetBrightness() {
    global ASDBCTL
    out := RunSilentCapture(Format('"{1}" get', ASDBCTL))
    return RegExMatch(out, "brightness\s+(\d+)", &m) ? (m[1] + 0) : -1
}

Toast(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1200)
}

ShowAfter(direction) {
    BumpBrightness(direction)
    Toast("Brightness: " GetBrightness() "%")
}

LaunchUI() {
    global UI_SCRIPT
    Run('powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' UI_SCRIPT '"', , "Hide")
}

^!Up::ShowAfter("up")
^!Down::ShowAfter("down")
^!b::LaunchUI()
