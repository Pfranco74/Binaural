if not exist c:\Windows\Temp\Logs\MsTeams md c:\Windows\Temp\Logs\MsTeams
if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\MsTeams.log

powershell -ExecutionPolicy Bypass -file Sith_Msteams.ps1

echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\MsTeams.log

exit 0