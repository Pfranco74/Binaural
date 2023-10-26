function Manufacturer
{
    $Manufacturer = ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer).toupper()
    
    if ($Manufacturer -eq 'HEWLETT-PACKARD')
    {
        $Manufacturer = 'HP'
    }

    Return $Manufacturer
}

function HPBios
{
    $InterFacePW = Get-WmiObject -class HP_BiosSetting -namespace root\hp\InstrumentedBios
    $InterFace = Get-WmiObject -class HP_BiosSettingInterface -namespace root\hp\InstrumentedBios
    $check = ($InterFacepw | Where-Object Name -eq "Setup Password").isset
    $HPPar = @("Mill2013","Mill2009")
    $old = $null

    foreach ($item in $HPPar)
    {

        if(($Interface.SetBIOSSetting("Setup Password","<utf-16/>" + $item,"<utf-16/>" + $item)).Return -eq 0)
        {
            $old = $item
            Return $item
        } 
    }
    if ($old -ne $null)
    {
        If(($Interface.SetBIOSSetting("Setup Password","<utf-16/>" + $new,"<utf-16/>" + $old)).Return -eq 0)
        {
            #Return $new 
        }           
    }

    Write-Output "Wrong Bios Password"
    Stop-Transcript
    exit 1
}

function ForceErr
{
    Write-Output "Detect Error"
    Stop-Transcript -ErrorAction SilentlyContinue
    Copy-Item -Path "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.log" -Destination "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.nok" -Force
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.log" -Force
    exit 1
}


# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\Bios"))
{
    Mkdir "C:\Windows\Temp\Logs\Bios"
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.log"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.log" -Force
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.nok"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.nok" -Force
}


# Start logging
Start-Transcript "C:\Windows\Temp\Logs\Bios\HP_Bios_Update.log"
#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }
}

try
{
    $Manufacturer = Manufacturer
    $HPPar1 = HPBios

    # HP BIOS Block
    if ($Manufacturer -eq 'HP')
    {
        Import-Module HP.ClientManagement -Force -ErrorAction SilentlyContinue

        # Get Install Version
        $BiosVersion = Get-HPBIOSVersion
        # Get Repository Latest Version
        $BiosVersionLatest = (Get-HPBIOSUpdates -Latest).ver

        if ($BiosVersionLatest -NE $BiosVersion)
        {
            $BIOSCheck = Get-HPBIOSUpdates -Check

            if ($BIOSCheck -eq $True)
            {     
                # Update Bios      
                Get-HPBIOSUpdates -Flash -BitLocker Suspend -Force -Overwrite -Password $HPPar1 -Quiet -Yes
                Stop-Transcript
                exit 1641            
            }     
        }
    Else
    {
        Write-Output "Same Bios Version"
        Stop-Transcript
        exit 0
    }
}
    Else
    {
        Write-Output "Skip Update not HP Model"
        Stop-Transcript
        exit 0
    }
}
catch
{
    ForceErr
}
Stop-Transcript