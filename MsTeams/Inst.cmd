if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_Lenovo_BiosConfig.log
powershell -ExecutionPolicy Bypass -file Sith_Lenovo_BiosConfig.ps1

if %errorlevel% == 0 goto end
if %errorlevel% == 3010 goto end
if %errorlevel% == 1641 goto end
:error
ren "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Config.log" Lenovo_BIOS_Config.nok

:end
echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\Sith_Lenovo_BiosConfig.log