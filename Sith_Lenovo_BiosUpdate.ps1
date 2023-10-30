CLS

function Manufacturer
{
    $Manufacturer = ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer).toupper()
    
    if ($Manufacturer -eq 'HEWLETT-PACKARD')
    {
        $Manufacturer = 'HP'
    }

    write-host $Manufacturer -ForegroundColor Green

    Return $Manufacturer
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

 #Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\Bios"))
{
    Mkdir "C:\Windows\Temp\Logs\Bios"
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.log"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.log" -Force
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.nok"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.nok" -Force
}

if (-not (Test-Path "C:\Windows\Temp\Bios\Lenovo"))
{
    Mkdir "C:\Windows\Temp\Bios\Lenovo"
}

# Start logging
Start-Transcript "C:\Windows\Temp\Logs\Bios\Lenovo_Bios_Update.log"
Write-Host "Begin"
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'

Write-Host "Start Bios Update Process"


try
{
    $Manufacturer = Manufacturer


    if ($Manufacturer -eq 'LENOVO')
    {
        Write-Host "Install Lenovo PS Module"
        Install-Module -Name LSUClient -Force
        Import-Module -Name LSUClient

        #$drvlist = Get-LSUpdate -All -Model 10FL | Where-Object { $_.Installer.Unattended }
        #$drvlist | Save-LSUpdate -Path C:\Windows\Temp\Bios\Lenovo -ShowProgress
        Write-Host "Get Lenovo Update from WEB"
        $drvlist = Get-LSUpdate -all | Where-Object {-not $_.IsInstalled }
        $BiosUpdate = $null

        foreach ($item in $drvlist)
        {
            if (($item.type) -like "*BIOS*")
            {
                write-host "Check for BIOS Update"
                $BiosUpdate = $item
            }
        }

        if ($BiosUpdate -EQ $null)
        {
            $ToDo = "Nothing to Do - Bios Update"
            Write-Output $ToDo
            Stop-Transcript
            [Environment]::Exit(0)
        }
        else
        {
            #$BiosUpdate | Install-LSUpdate -Verbose
            write-host "Start Bios update on computer"
            $BiosUpdate | Save-LSUpdate -Path C:\Windows\Temp\Bios\Lenovo -ShowProgress
    
            $List = Get-ChildItem -Path C:\Windows\Temp\Bios\Lenovo -Recurse -Filter *.exe

            $program = $list.FullName
            $arg = "/verysilent /norestart"

            $run = ( Start-Process $program -ArgumentList $arg -PassThru )

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
                
                        $run = ( Start-Process -Wait $item.name -PassThru) 

                        Set-Location c:\

                        Remove-Item -Path C:\SWTOOLS -Force -Recurse
                        Remove-Item -Path C:\Windows\Temp\Bios\Lenovo -Force -Recurse

                        write-host "Exit with hard reboot"

                        Stop-Transcript

                        [Environment]::Exit(1641)
                    }
                }
            }

            if ((Test-Path "C:\Drivers"))
            {
                write-host "Start bios update om computer"

                $flash = Get-ChildItem -Path C:\Drivers -Recurse -Filter *.exe

                foreach ($item in $flash)
                {
                    if ($Item.name -eq "winuptp64.exe")
                    {                
                        Set-Location ($item.Directory).FullName
                        $arg = "-s"

                        $run = ( Start-Process -Wait $item.name -ArgumentList $arg -PassThru) 

                        Set-Location c:\

                        Remove-Item -Path C:\Drivers -Force -Recurse
                        Remove-Item -Path C:\Windows\Temp\Bios\Lenovo -Force -Recurse
                        
                        write-host "Exit with hard reboot"

                        Stop-Transcript

                        [Environment]::Exit(1641)

                    }
                }
            }
        }
    }
    Else
    {
        Write-Output "Skip Update not Lenovo Model"
        Stop-Transcript
        [Environment]::Exit(0)
    }
}
Catch
{
    Write-Output "Detect Error"
    Stop-Transcript
    Rename-Item -Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.log" -NewName "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.NOK"
    
    if ((Test-Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.log"))
    {
        Remove-Item -Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Update.log" -Force
    }

    [Environment]::Exit(1)
}

Stop-Transcript