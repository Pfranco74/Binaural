 CLS
 #Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\Bios"))
{
    Mkdir "C:\Windows\Temp\Logs\Bios"
}


# Start logging
Start-Transcript "C:\Windows\Temp\Logs\Bios\Lenovo_Update.log"

if (-not (Test-Path "C:\Windows\Temp\Bios\Lenovo"))
{
    Mkdir "C:\Windows\Temp\Bios\Lenovo"
}

if (-not (Test-Path "C:\Windows\Temp\Logs\Bios"))
{
    Mkdir "C:\Windows\Temp\Logs\Bios"
}


# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }
}


Install-Module -Name LSUClient -Force
Import-Module -Name LSUClient

#$drvlist = Get-LSUpdate -All -Model 10FL | Where-Object { $_.Installer.Unattended }
#$drvlist | Save-LSUpdate -Path C:\Windows\Temp\Bios\Lenovo -ShowProgress
$drvlist = Get-LSUpdate -all -Verbose | Where-Object {-not $_.IsInstalled }
$BiosUpdate = $null

foreach ($item in $drvlist)
{
    if (($item.type) -like "*BIOS*")
    {
        $BiosUpdate = $item
    }
}

if ($BiosUpdate -EQ $null)
{
    $ToDo = "Nothing to Do"
    Write-Output $ToDo
    Stop-Transcript
    exit 0    
}
else
{
    #$BiosUpdate | Install-LSUpdate -Verbose
    $BiosUpdate | Save-LSUpdate -Path C:\Windows\Temp\Bios\Lenovo -ShowProgress

    $List = Get-ChildItem -Path C:\Windows\Temp\Bios\Lenovo -Recurse -Filter *.exe

    $program = $list.FullName
    $arg = "/verysilent /norestart /log=C:\Windows\Temp\Logs\Bios\Lenovo\BiosUpdate.log"

    $run = ( Start-Process $program $arg -PassThru) 

    Start-Sleep -Seconds 5

    Get-Process -Name Winuptp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    if ((Test-Path "C:\SWTOOLS"))
    {
        $flash = Get-ChildItem -Path C:\SWTOOLS -Recurse -Filter *.cmd

        foreach ($item in $flash)
        {
            if ($Item.name -like "*quiet*")
            {                
                Set-Location ($item.Directory).FullName
                #$run = ( Start-Process -Wait $item.name -PassThru) 
            }
        }
    }

    if ((Test-Path "C:\Drivers"))
    {
        $flash = Get-ChildItem -Path C:\Drivers -Recurse -Filter *.exe

        foreach ($item in $flash)
        {
            if ($Item.name -eq "winuptp64.exe")
            {                
                Set-Location ($item.Directory).FullName
                $arg = "-s"

                #$run = ( Start-Process -Wait $item.name -ArgumentList $arg -PassThru) 
            }
        }
    }

}