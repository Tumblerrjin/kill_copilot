**for those of us that have to use microsoft but cant stand copilot**

This is a tiny Windows script I made because Copilot kept hanging around in the background and I wanted it gone.

Put `kill_copilot.vbs` in your Windows startup folder and it will check every 5 minutes for Copilot processes.

How it works: When you log in, it waits 45 seconds, checks for Copilot, and kills it if it's running. After that it checks again every 5 minutes.

If Copilot isn't running, it does nothing.

If it finds it, it kills `M365Copilot.exe`, cleans up the Copilot WebView processes that get left behind, clears the dead tray icon, and gives you a little notification:

> Copilot successfully murdered :)

I've tested this on Windows 10.

To install it and have it run in bg:

1. Download `kill_copilot.vbs`
2. Right click it and go to **Properties**
3. Check **Unblock** if Windows gives you the option
4. Press `Win + R`
5. Type `shell:startup`
6. Drop `kill_copilot.vbs` in that folder

It also keeps a little status log here:

`%LOCALAPPDATA%\kill_copilot_status.txt`

If you ever want to make sure it's actually running, open that file and it'll tell you when it last checked and whether it killed anything.

It doesn't uninstall Copilot or modify Windows. It just checks every few minutes and kills Copilot whenever it catches it running.

If you want to get rid of it, delete `kill_copilot.vbs` from your Startup folder and restart/log out.

Microsoft will inevitably change something eventually and break this, but as of right now it's working on my Windows 10 machine with `M365Copilot.exe`.

MIT licensed. Do whatever you want with it.
