#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; --- Config ---
ResolveAsdbctl() {
    candidates := [
        A_ScriptDir "\target\release\asdbctl.exe",
        A_ScriptDir "\asdbctl.exe",
        EnvGet("USERPROFILE") "\Tools\asdbctl\target\release\asdbctl.exe",
        EnvGet("USERPROFILE") "\Tools\asdbctl\asdbctl.exe"
    ]
    for c in candidates {
        if FileExist(c)
            return c
    }
    return "asdbctl.exe"
}

ASDBCTL := ResolveAsdbctl()
STEP := 5
OSD_DURATION_MS := 900
POPUP_AUTOHIDE_MS := 4000
TRAY_ICON := "C:\Windows\System32\imageres.dll"
TRAY_ICON_INDEX := 110

; --- Shared state ---
popupVisible := false
sliderPendingValue := -1
sliderInFlight := false
sliderInFlightPid := 0

; --- Backend ---
RunSilent(cmd) {
    RunWait(A_ComSpec ' /S /C "' cmd '"', , "Hide")
}

RunSilentAsync(cmd) {
    Run(A_ComSpec ' /S /C "' cmd '"', , "Hide", &pid)
    return pid
}

RunSilentCapture(cmd) {
    tmp := A_Temp "\asdctl_" A_TickCount "_" Random(1000, 9999) ".txt"
    RunWait(A_ComSpec ' /S /C "' cmd ' > ' tmp ' 2>&1"', , "Hide")
    out := FileExist(tmp) ? FileRead(tmp) : ""
    try FileDelete(tmp)
    return out
}

GetBrightness() {
    global ASDBCTL
    out := RunSilentCapture(Format('"{1}" get', ASDBCTL))
    return RegExMatch(out, "brightness\s+(\d+)", &m) ? (m[1] + 0) : -1
}

SetBrightness(v) {
    global ASDBCTL
    v := Max(0, Min(100, Integer(v)))
    RunSilent(Format('"{1}" set {2}', ASDBCTL, v))
    return v
}

SetBrightnessAsync(v) {
    global ASDBCTL
    v := Max(0, Min(100, Integer(v)))
    return RunSilentAsync(Format('"{1}" set {2}', ASDBCTL, v))
}

; --- OSD: macOS-style centered top overlay ---
osdGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "ASD_OSD")
osdGui.BackColor := "202020"
osdGui.MarginX := 0
osdGui.MarginY := 0
osdGui.SetFont("s28 cFFFFFF Bold q5", "Segoe UI")
osdText := osdGui.AddText("w300 h90 Center 0x200", "")
WinSetTransparent(225, osdGui)

HideOsd() {
    osdGui.Hide()
}

ShowOSD(text, isError := false) {
    global osdGui, osdText
    osdText.Opt(isError ? "cFF6060" : "cFFFFFF")
    osdText.Text := text
    x := (A_ScreenWidth - 300) // 2
    y := A_ScreenHeight // 6
    osdGui.Show(Format("w300 h90 NoActivate x{1} y{2}", x, y))
    SetTimer(HideOsd, -OSD_DURATION_MS)
}

; --- Slider popup ---
popup := Gui("+AlwaysOnTop -Caption +ToolWindow", "ASD Brightness")
popup.BackColor := "2C2C2C"
popup.MarginX := 12
popup.MarginY := 10
popup.SetFont("s10 cFFFFFF q5", "Segoe UI")
popupLabel := popup.AddText("w200 h18 Center", "Brightness: --%")
sliderCtrl := popup.AddSlider("xm y+6 w200 h28 Range0-100 TickInterval10 ToolTip")
sliderCtrl.OnEvent("Change", OnSliderChange)
popup.OnEvent("Escape", HidePopupEvent)

OnSliderChange(ctrl, info) {
    global popupLabel, sliderPendingValue
    popupLabel.Text := Format("Brightness: {1}%", ctrl.Value)
    sliderPendingValue := ctrl.Value
    PumpSlider()
}

PumpSlider() {
    global sliderInFlight, sliderInFlightPid, sliderPendingValue
    if sliderInFlight
        return
    if (sliderPendingValue < 0)
        return
    v := sliderPendingValue
    sliderPendingValue := -1
    sliderInFlight := true
    sliderInFlightPid := SetBrightnessAsync(v)
    SetTimer(SliderWatchTick, 30)
}

SliderWatchTick() {
    global sliderInFlight, sliderInFlightPid
    if !ProcessExist(sliderInFlightPid) {
        SetTimer(SliderWatchTick, 0)
        sliderInFlight := false
        sliderInFlightPid := 0
        PumpSlider()
    }
}

; WM_HSCROLL hook: AHK Slider's "Change" event only fires on thumb release,
; so we tap into the underlying Win32 trackbar SB_THUMBTRACK notification
; to get continuous position updates while the user drags.
OnSliderHScroll(wParam, lParam, msg, hwnd) {
    global sliderCtrl, popupLabel, popupVisible, sliderPendingValue
    if !popupVisible
        return
    if (lParam != sliderCtrl.Hwnd)
        return
    code := wParam & 0xFFFF
    if (code != 5 && code != 4)  ; SB_THUMBTRACK / SB_THUMBPOSITION
        return
    pos := SendMessage(0x400, 0, 0, sliderCtrl)  ; TBM_GETPOS
    pos := Max(0, Min(100, pos))
    sliderCtrl.Value := pos
    popupLabel.Text := Format("Brightness: {1}%", pos)
    sliderPendingValue := pos
    PumpSlider()
}
OnMessage(0x114, OnSliderHScroll)  ; WM_HSCROLL

POPUP_MARGIN_X := 12
POPUP_MARGIN_Y := 50

ShowSlider() {
    global popup, popupVisible, sliderCtrl, popupLabel, POPUP_MARGIN_X, POPUP_MARGIN_Y
    cur := GetBrightness()
    if (cur < 0) {
        ShowOSD("Studio Display not connected", true)
        return
    }
    sliderCtrl.Value := cur
    popupLabel.Text := Format("Brightness: {1}%", cur)
    popup.Show("AutoSize Hide NoActivate")
    WinGetPos(, , &pw, &ph, popup.Hwnd)
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    x := r - pw - POPUP_MARGIN_X
    y := b - ph - POPUP_MARGIN_Y
    popup.Show(Format("x{1} y{2} NoActivate", x, y))
    WinSetAlwaysOnTop(true, popup.Hwnd)
    popupVisible := true
    SetTimer(AutoHidePopup, -POPUP_AUTOHIDE_MS)
}

HidePopup() {
    global popup, popupVisible
    if popupVisible {
        popup.Hide()
        popupVisible := false
    }
}

HidePopupEvent(*) {
    HidePopup()
}

AutoHidePopup() {
    global popupVisible
    if popupVisible && !WinActive("ASD Brightness ahk_class AutoHotkeyGUI") {
        HidePopup()
    } else if popupVisible {
        SetTimer(AutoHidePopup, -POPUP_AUTOHIDE_MS)
    }
}

; Lose-focus auto-hide
OnMessage(0x06, OnWmActivate)
OnWmActivate(wParam, lParam, msg, hwnd) {
    global popup, popupVisible
    if !popupVisible
        return
    if (wParam = 0 && hwnd = popup.Hwnd) {
        SetTimer(() => HidePopup(), -150)
    }
}

; --- Tray ---
try TraySetIcon(TRAY_ICON, TRAY_ICON_INDEX)
A_IconTip := "ASD Brightness"
A_TrayMenu.Delete()
A_TrayMenu.Add("Open slider", (*) => ShowSlider())
A_TrayMenu.Add()
A_TrayMenu.Add("Brightness 100%", (*) => QuickSet(100))
A_TrayMenu.Add("Brightness 75%",  (*) => QuickSet(75))
A_TrayMenu.Add("Brightness 50%",  (*) => QuickSet(50))
A_TrayMenu.Add("Brightness 25%",  (*) => QuickSet(25))
A_TrayMenu.Add("Brightness 0%",   (*) => QuickSet(0))
A_TrayMenu.Add()
A_TrayMenu.Add("About",  AboutClick)
A_TrayMenu.Add("Exit",   (*) => ExitApp())
A_TrayMenu.Default := "Open slider"
A_TrayMenu.ClickCount := 1

QuickSet(v) {
    SetBrightness(v)
    ShowOSD(Format("{1}%", v))
}

AboutClick(*) {
    MsgBox(
        "asd-tray-windows`n`n"
        "Tray daemon for Apple Studio Display brightness on Windows.`n"
        "Backend: juliuszint/asdbctl`n`n"
        "https://github.com/zywang0108/asd-tray-windows",
        "About",
        "Iconi 4096"
    )
}

; --- Global hotkeys ---
^!Up::HotkeyBump(STEP)
^!Down::HotkeyBump(-STEP)
^!b::ShowSlider()

HotkeyBump(delta) {
    cur := GetBrightness()
    if (cur < 0) {
        ShowOSD("Studio Display not connected", true)
        return
    }
    newV := Max(0, Min(100, cur + delta))
    SetBrightness(newV)
    ShowOSD(Format("{1}%", newV))
    global popupVisible, sliderCtrl
    if popupVisible
        sliderCtrl.Value := newV
}

; --- Wheel over slider popup ---
#HotIf WinActive("ASD Brightness ahk_class AutoHotkeyGUI")
WheelUp::WheelBump(STEP)
WheelDown::WheelBump(-STEP)
#HotIf

WheelBump(delta) {
    global sliderCtrl
    newV := Max(0, Min(100, sliderCtrl.Value + delta))
    sliderCtrl.Value := newV
    OnSliderChange(sliderCtrl, 0)
    SetTimer(AutoHidePopup, -POPUP_AUTOHIDE_MS)
}
