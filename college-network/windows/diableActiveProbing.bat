REM Source - https://support.microsoft.com/en-in/help/4494446/an-internet-explorer-or-edge-window-opens-when-your-computer-connects
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" /v EnableActiveProbing /t REG_DWORD /d 0 /f
