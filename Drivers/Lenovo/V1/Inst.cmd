if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_Lenovo_Drivers.log
powershell -ExecutionPolicy Bypass -file Sith_Lenovo_Drivers.ps1

:end
echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_Lenovo_Drivers.log
EXIT %EXITCODE%