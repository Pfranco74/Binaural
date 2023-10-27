CLS
 
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

    Return "BushBush"
}

function Manufacturer
{
    $Manufacturer = ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer).toupper()
    
    if ($Manufacturer -eq 'HEWLETT-PACKARD')
    {
        $Manufacturer = 'HP'
    }

    Return $Manufacturer
}

 #Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\Bios"))
{
    Mkdir "C:\Windows\Temp\Logs\Bios"
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\HP_BIOS_Config.log"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\HP_BIOS_Config.log" -Force
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\HP_BIOS_Config.nok"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\HP_BIOS_Config.nok" -Force
}

# Start logging
Start-Transcript "C:\Windows\Temp\Logs\Bios\HP_BIOS_Config.log"


# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }
}


$Manufacturer = Manufacturer

# HP BIOS Block
if ($Manufacturer -eq 'HP')
{

    $HPPar1 = HPBios
    if ($HPPar1 -eq "BushBush")
    {
        Write-Output "Detect BIOS PW Error"
        exit 1        
    }
    $AllBiosSettings = Get-WmiObject -class HP_BiosEnumeration -namespace root\hp\InstrumentedBios
    $BiosSettings = $AllBiosSettings | Select-Object name,CurrentValue
    $InterFace = Get-WmiObject -class HP_BiosSettingInterface -namespace root\hp\InstrumentedBios


    $MBCPSettings = @("TPM State,Enable")

    foreach ($item in $MBCPSettings)
    {
        $Setting = $item.Split(",")[0]
        $value = $item.Split(",")[1]
        foreach ($item1 in $BiosSettings)
        {
            $CpuSetting = $item1.name
            $Cpuvalue = $item1.currentvalue

            if ($Setting -eq $CpuSetting)
            {
                if ($value -eq $Cpuvalue)
                {
                    $ToDo = "Nothing to Do - Setting:" + $CpuSetting +  " Value: " + $Cpuvalue
                    Write-Output $ToDo
                }
                Else
                {
                    $setvalue = ($Interface.SetBIOSSetting($Setting,$Value,"<utf-16/>" + $HPPar1))
                    if (($setvalue.return) -ne "0")
                    {
                        Write-Output $Setting
                        Write-Output $value
                        Write-Output "Error Setting Bios Value"

                        exit 1
                    }
                    Else
                    {
                        $ToDo = "Change - Setting:" + $Setting +  " Value: " + $value
                        Write-Output $ToDo
                    }
                }            
            } 
        }
    }
}
Else
{
    Write-Output "Skip Update not HP Model"
    Stop-Transcript
    exit 0
}

Stop-Transcript