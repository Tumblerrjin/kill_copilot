Option Explicit
On Error Resume Next

Dim shell, fso, wmi
Dim statusPath, startedAt
Dim selfCount, p, procs
Dim matched, key, info
Dim attempts, killedAny, killedList
Dim remaining, remainingList
Dim psCommand

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set wmi = GetObject("winmgmts:\\.\root\cimv2")

statusPath = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\kill_copilot_status.txt"
startedAt = Now

Sub WriteStatus(state, details)
    Dim file, text
    text = "kill_copilot watchdog" & vbCrLf & _
           "Started: " & CStr(startedAt) & vbCrLf & _
           "Last check: " & CStr(Now) & vbCrLf & _
           "State: " & state & vbCrLf & _
           details & vbCrLf

    Set file = fso.CreateTextFile(statusPath, True)
    file.Write text
    file.Close
End Sub

Function IsCopilotProcess(procName, procCmd, procPath)
    Dim n, c, x
    n = LCase("" & procName)
    c = LCase("" & procCmd)
    x = LCase("" & procPath)

    IsCopilotProcess = False

    If InStr(n, "copilot") > 0 Then
        If n <> "wscript.exe" And n <> "cscript.exe" And n <> "powershell.exe" Then
            IsCopilotProcess = True
            Exit Function
        End If
    End If

    If InStr(c, "microsoft.copilot_") > 0 Then IsCopilotProcess = True
    If InStr(c, "\microsoft\copilot\") > 0 Then IsCopilotProcess = True
    If InStr(c, "copilot.microsoft.com") > 0 Then IsCopilotProcess = True
    If InStr(c, "copilot.exe") > 0 Then IsCopilotProcess = True

    If InStr(x, "microsoft.copilot_") > 0 Then IsCopilotProcess = True
    If InStr(x, "\microsoft\copilot\") > 0 Then IsCopilotProcess = True
End Function

Function FindCopilotProcesses()
    Dim d, allProcs, proc, procName, procCmd, procPath, procPid
    Set d = CreateObject("Scripting.Dictionary")

    Err.Clear
    Set allProcs = wmi.ExecQuery( _
        "SELECT Name, ProcessId, CommandLine, ExecutablePath FROM Win32_Process" _
    )

    If Err.Number <> 0 Then
        Set FindCopilotProcesses = d
        Err.Clear
        Exit Function
    End If

    For Each proc In allProcs
        procName = "" & proc.Name
        procCmd = "" & proc.CommandLine
        procPath = "" & proc.ExecutablePath
        procPid = CStr(proc.ProcessId)

        If IsCopilotProcess(procName, procCmd, procPath) Then
            If Not d.Exists(procPid) Then
                d.Add procPid, procName
            End If
        End If
    Next

    Set FindCopilotProcesses = d
End Function

Sub RefreshTray()
    Dim refreshCmd

    refreshCmd = "powershell.exe -NoProfile -WindowStyle Hidden -Command " & _
    """$src = @'" & vbCrLf & _
    "using System;" & vbCrLf & _
    "using System.Runtime.InteropServices;" & vbCrLf & _
    "public static class TrayRefresh {" & vbCrLf & _
    "  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }" & vbCrLf & _
    "  [DllImport(""user32.dll"", SetLastError=true)] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);" & vbCrLf & _
    "  [DllImport(""user32.dll"", SetLastError=true)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr childAfter, string className, string windowTitle);" & vbCrLf & _
    "  [DllImport(""user32.dll"")] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);" & vbCrLf & _
    "  [DllImport(""user32.dll"")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);" & vbCrLf & _
    "}" & vbCrLf & _
    "'@;" & _
    "Add-Type $src -ErrorAction SilentlyContinue;" & _
    "$WM_MOUSEMOVE=0x0200;" & _
    "function Sweep([IntPtr]$h) {" & _
    " if($h -eq [IntPtr]::Zero){return};" & _
    " $r=New-Object TrayRefresh+RECT;" & _
    " if([TrayRefresh]::GetClientRect($h,[ref]$r)){" & _
    "   for($y=2;$y -lt $r.Bottom;$y+=8){" & _
    "     for($x=2;$x -lt $r.Right;$x+=8){" & _
    "       $lp=[IntPtr](($y -shl 16) -bor ($x -band 0xFFFF));" & _
    "       [void][TrayRefresh]::SendMessage($h,$WM_MOUSEMOVE,[IntPtr]::Zero,$lp)" & _
    "     }" & _
    "   }" & _
    " }" & _
    "};" & _
    "$tray=[TrayRefresh]::FindWindow('Shell_TrayWnd',$null);" & _
    "$notify=[TrayRefresh]::FindWindowEx($tray,[IntPtr]::Zero,'TrayNotifyWnd',$null);" & _
    "$pager=[TrayRefresh]::FindWindowEx($notify,[IntPtr]::Zero,'SysPager',$null);" & _
    "$toolbar=[TrayRefresh]::FindWindowEx($pager,[IntPtr]::Zero,'ToolbarWindow32',$null);" & _
    "Sweep $toolbar;" & _
    "$overflow=[TrayRefresh]::FindWindow('NotifyIconOverflowWindow',$null);" & _
    "$overflowToolbar=[TrayRefresh]::FindWindowEx($overflow,[IntPtr]::Zero,'ToolbarWindow32',$null);" & _
    "Sweep $overflowToolbar;"""

    shell.Run refreshCmd, 0, True
End Sub

Sub SendNotification()
    psCommand = "powershell.exe -NoProfile -WindowStyle Hidden -Command " & _
        """Add-Type -AssemblyName System.Windows.Forms; " & _
        "Add-Type -AssemblyName System.Drawing; " & _
        "$n = New-Object System.Windows.Forms.NotifyIcon; " & _
        "$n.Icon = [System.Drawing.SystemIcons]::Information; " & _
        "$n.BalloonTipTitle = 'kill_copilot'; " & _
        "$n.BalloonTipText = 'Copilot successfully murdered :)'; " & _
        "$n.Visible = $true; " & _
        "$n.ShowBalloonTip(5000); " & _
        "Start-Sleep -Seconds 6; " & _
        "$n.Dispose()"""

    shell.Run psCommand, 0, False
End Sub

' Prevent multiple copies of this watchdog from running at once.
selfCount = 0
Set procs = wmi.ExecQuery( _
    "SELECT Name, CommandLine FROM Win32_Process " & _
    "WHERE Name='wscript.exe' OR Name='cscript.exe'" _
)

For Each p In procs
    If InStr(1, "" & p.CommandLine, "kill_copilot.vbs", vbTextCompare) > 0 Then
        selfCount = selfCount + 1
    End If
Next

If selfCount > 1 Then
    WScript.Quit
End If

WriteStatus "waiting", _
    "Single watchdog active. First Copilot sweep runs after the 45-second startup delay."

WScript.Sleep 45000

Do
    killedAny = False
    killedList = ""

    Set matched = FindCopilotProcesses()

    If matched.Count > 0 Then
        For attempts = 1 To 3
            Set matched = FindCopilotProcesses()

            If matched.Count = 0 Then Exit For

            For Each key In matched.Keys
                info = matched(key)

                shell.Run _
                    "taskkill.exe /F /T /PID " & key, _
                    0, True

                killedAny = True

                If InStr(1, killedList, info & " (PID " & key & ")", vbTextCompare) = 0 Then
                    If killedList <> "" Then killedList = killedList & ", "
                    killedList = killedList & info & " (PID " & key & ")"
                End If
            Next

            WScript.Sleep 1500
        Next
    End If

    Set remaining = FindCopilotProcesses()
    remainingList = ""

    If remaining.Count > 0 Then
        For Each key In remaining.Keys
            If remainingList <> "" Then remainingList = remainingList & ", "
            remainingList = remainingList & remaining(key) & " (PID " & key & ")"
        Next
    End If

    If killedAny And remaining.Count = 0 Then
        ' Give Explorer a moment, then sweep the tray to clear stale icons.
        WScript.Sleep 1000
        RefreshTray

        WriteStatus "COPILOT KILLED", _
            "Killed Copilot process tree / leftovers: " & killedList & vbCrLf & _
            "No matching Copilot processes remain." & vbCrLf & _
            "Notification area refresh requested. Next check in 5 minutes."

        SendNotification

    ElseIf killedAny And remaining.Count > 0 Then
        WriteStatus "COPILOT STILL PRESENT", _
            "Kill attempted against: " & killedList & vbCrLf & _
            "Still detected: " & remainingList & vbCrLf & _
            "Next check in 5 minutes."

    Else
        WriteStatus "running", _
            "No Copilot process or Copilot WebView/package process detected. Next check in 5 minutes."
    End If

    WScript.Sleep 300000
Loop
