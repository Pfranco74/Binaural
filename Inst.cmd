if not exist c:\Windows\Temp\Logs\Dotnet35 md c:\Windows\Temp\Logs\Dotnet35
if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\DotNet35.log

powershell -ExecutionPolicy Bypass -file DotNet35.ps1

echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\DotNet35.log