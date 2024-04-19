if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_HP_BiosUpdate.log
powershell -ExecutionPolicy Bypass -file Sith_HP_BiosUpdate.ps1


if %errorlevel% == 0 set EXITCODE=0
if %errorlevel% == 3010 set EXITCODE=3010
if %errorlevel% == 1641 set EXITCODE=1641

if %errorlevel% == 0 goto end
if %errorlevel% == 3010 goto end
if %errorlevel% == 1641 goto end

:error
ren "C:\Windows\Temp\Logs\Bios\HP_BIOS_Update.log" HP_BIOS_Update.nok
set EXITCODE=1

:end
echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_HP_BiosConfig.log
EXIT %EXITCODE%