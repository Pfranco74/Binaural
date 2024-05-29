[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path "D:\HASH"))
{
  Mkdir "D:\HASH"
}

Set-Location -Path "D:\HASH"
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Install-Script -Name Get-WindowsAutopilotInfo -force
Get-WindowsAutopilotInfo -OutputFile AutopilotHWID.csv
