if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_UpdateOS_SEC.log

powershell -ExecutionPolicy Bypass -file Sith_UpdateOS_SEC.ps1


if %errorlevel% == 0 set EXITCODE=0
if %errorlevel% == 3010 set EXITCODE=3010
if %errorlevel% == 1641 set EXITCODE=1641
set EXITCODE == %errorlevel%

echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_UpdateOS_SEC.log
EXIT %EXITCODE%
