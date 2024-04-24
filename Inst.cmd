if not exist c:\Windows\Temp\Logs\PKI md c:\Windows\Temp\Logs\PKI
if not exist c:\temp md c:\Temp
if not exist c:\Windows\Temp\Logs\AutoPilot md c:\Windows\Temp\Logs\AutoPilot

echo Begin %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\PKI.log

msiexec.exe /i "Setup.Management.v.2.0.msi" /quiet /norestart /l*v c:\Windows\Temp\Logs\PKI\pki_inst.log

echo End %date% %time% >> c:\Windows\Temp\Logs\AutoPilot\PKI.log