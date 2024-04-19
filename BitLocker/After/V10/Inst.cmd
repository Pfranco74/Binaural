if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_BitLocker.log
powershell -ExecutionPolicy Bypass -file Sith_BitLocker.ps1

if %errorlevel% == 0 set EXITCODE=0
if %errorlevel% == 3010 set EXITCODE=3010
if %errorlevel% == 1641 set EXITCODE=1641

if %errorlevel% == 0 goto end
if %errorlevel% == 3010 goto end
if %errorlevel% == 1641 goto end

:error
if exist C:\Windows\Temp\Logs\BitLocker\BitLocker.log ren "C:\Windows\Temp\Logs\BitLocker\BitLocker.log" BitLocker.nok
set EXITCODE=1

:end
echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_BitLocker.log
EXIT %EXITCODE%