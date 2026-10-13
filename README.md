**Do you hate Copilot? same.**

This is a tiny Windows script I made because Copilot kept hanging around in the background and I wanted it gone.

Put `kill_copilot.vbs` in your startup folder and it will check every 5 minutes for Copilot processes.

How it works: When you log in, it waits 45 seconds, checks for Copilot, and kills it if it's running. After that it checks again every 5 minutes.

If Copilot isn't running, it does nothing.

If it finds it, it kills `M365Copilot.exe`, cleans up the Copilot WebView processes that get left behind, clears the dead tray icon, and gives you a little notification:

> Copilot successfully murdered :)

Tested and working on Windows 10.

install:

1. Download `kill_copilot.vbs`
2. Right click it and go to **Properties**
3. Check **Unblock** if Windows gives you the option
4. Press `Win + R`
5. Type `shell:startup`
6. Drop `kill_copilot.vbs` in that folder

also keeps a status log:

`%LOCALAPPDATA%\kill_copilot_status.txt`

This fix does not uninstall Copilot or modify Windows. It just checks every few minutes and kills Copilot whenever it catches it running without direct permission.

If you want to get rid of it, delete `kill_copilot.vbs` from your Startup folder and restart windows.

Microsoft will inevitably change something eventually and break this, at which point I will update this to continue working. ,,|,, 

Still working as of 10/13/26.
