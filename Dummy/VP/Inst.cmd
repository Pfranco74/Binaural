if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_Dummy.log
powershell -ExecutionPolicy Bypass -file Sith_Dummy.ps1
echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_Dummy.log