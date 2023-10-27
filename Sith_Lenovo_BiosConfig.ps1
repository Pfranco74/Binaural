CLS

function LenovoBios
{
    $LenovoPar = @("Mill2013","Mill2009")
    $old = $null
    foreach ($item in $LenovoPar)
    {
        $Test = (Get-WmiObject -class Lenovo_SaveBiosSettings -namespace root\wmi).SaveBiosSettings("$item,ascii,us”)    
        if (($Test.return).ToUpper() -eq "SUCCESS")
        {
            $old = $item
            Return $item
        } 
    }
    if ($old -ne $null)
    {
        #$change = (Get-WmiObject -Class Lenovo_SetBiosPassword -Namespace root\wmi).SetBiosPassword("pap,$item,$new,ascii,us")
        #if (($change.return).ToUpper() -eq "SUCCESS")
        #{
            #Return $new
        #} 
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

if ((Test-Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Config.log"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Config.log" -Force
}

if ((Test-Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Config.nok"))
{
    Remove-Item -Path "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Config.nok" -Force
}

# Start logging
Start-Transcript "C:\Windows\Temp\Logs\Bios\Lenovo_BIOS_Config.log"

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
if ($Manufacturer -eq 'LENOVO')
{
    $LenovoPar1 = LenovoBios
    if ($LenovoPar1 -eq "BushBush")
    {
        Write-Output "Detect BIOS PW Error"
        exit 1        
    }
    
    $AllBiosSettings = Get-WmiObject -class Lenovo_BiosSetting -namespace root\wmi
    $BiosSettings = @()
    $needsave = $null

    foreach ($item in $AllBiosSettings)
    {
        if ($item.CurrentSetting -ne "")
        {
            $BiosSettings += $item.CurrentSetting
        }        
    }

    $MBCPSettings = @("MACAddressPassThrough,Enable","HyperThreadingTechnology,Enable","USBKeyProvisioning,Disable","ThunderboltSecurityLevel,NoSecurity","PreBootForThunderboltDevice,Enable","PreBootForThunderboltUSBDevice,Enable","LockBIOSSetting,Disable","SecurityChip,Enable","TXTFeature,Enable","PhysicalPresenceForTpmClear,Disable","SecureRollBackPrevention,Disable","WindowsUEFIFirmwareUpdate,Enable","DataExecutionPrevention,Enable","VirtualizationTechnology,Enable","SecureBoot,Enable","DeviceGuard,Disable","BootMode,Quick","BootDeviceListF12Option,Enable","BootOrder,NVMe0:PCILAN","NetworkBoot,PCILAN","BootOrderLock,Enable","Physical Presence for Clear,Disabled","Security Chip 2.0,Enabled","Allow Flashing BIOS to a Previous Version,Yes","Secure Boot,Enabled","VT-d,Enabled","TxT,Enabled","Primary Boot Sequence,SATA 1:Network 1","Automatic Boot Sequence,SATA 1:Network 1")

    foreach ($item in $MBCPSettings)
    {
        $Setting = $item.Split(",")[0]
        $value = $item.Split(",")[1]
        foreach ($item1 in $BiosSettings)
        {
            $CpuSetting = $item1.Split(",")[0]
            $Cpuvalue = $item1.Split(",")[1]
            if ($Cpuvalue -like "*;*")
            {
                $Cpuvalue = $Cpuvalue.Split(";")[0]
            }
                           
            if ($Setting -eq $CpuSetting)
            {
                if ($value -EQ $Cpuvalue)
                {
                    $ToDo = "Nothing to Do - Setting:" + $CpuSetting +  " Value:" + $Cpuvalue
                    Write-Output $ToDo
                }
                else
                {
                    $needsave = $true
                    $setvalue = (Get-WmiObject -class Lenovo_SetBiosSetting –namespace root\wmi).SetBiosSetting("$Setting,$value,$LenovoPar1,ascii,us")
                    if (($setvalue.return).ToUpper() -ne "SUCCESS")
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
    if ($needsave -ne $null)
    {
        $Save = (Get-WmiObject -class Lenovo_SaveBiosSettings -namespace root\wmi).SaveBiosSettings("$LenovoPar1,ascii,us”)  
        if (($Save.return).ToUpper() -ne "SUCCESS")
        {
            Write-Output "Error saving Bios Settings"
                        
            exit 1

        }
        Else
        {
            $ToDo = "Successfuly Save Bios Settings"
            Stop-Transcript            
            Write-Output $ToDo
            exit 0
        }
    }
}
Else
{
    Write-Output "Skip Update not LENOVO Model"
    Stop-Transcript
    exit 0
}

Stop-Transcript