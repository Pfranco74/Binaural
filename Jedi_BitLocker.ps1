$scriptVersion = "20260504"

cls
Remove-Variable * -ErrorAction SilentlyContinue

Function LogWrite
{
	Param ([string]$logstring)
	$a = Get-Date
	$logstring = $a,$logstring
	Try
    {   
		Add-content $Logfile -value $logstring -ErrorAction silentlycontinue
	}
    Catch
    {
		$logstring="Invalid data encountered"
		Add-content $Logfile -value $logstring
	}
	write-host $logstring
}

function ForceErr
{
    Stop-Transcript
    Rename-Item -Path $LogFile -NewName $LogErr -Force
    
    if ((Test-Path $LogFile))
    {
        Remove-Item -Path $LogFile -Force
    }

    $intunelogerr = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $Logerr.Split("\")[-1] + ".log"
    Copy-Item $Logerr $intunelogerr -Force -ErrorAction SilentlyContinue
    

    exit 13    
}

function CreateDir ($param1)
{
    try
    {
        if (-not (Test-Path $param1))
        {
            Mkdir $param1
        }
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr
    }
   
}

function DelFile ($param1)
{
    try
    {
        if ((Test-Path $param1))
        {
            Remove-Item -Path $param1 -Force
        }
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr
    }
   
}

function AutoPilot ($param1,$param2)
{
    try
    {
       $msg = $param1 + " " + $param2
       Out-File -FilePath $LogAuto -InputObject $msg -Append -Force
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr
    }
   
}

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITECTURE" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }
}
# Start logging
$LogAuto = "C:\Programdata\MBCP\Intune\AutoPilot\Logs\AutoPilot\BitLocker.log"
$DirAuto = "C:\Programdata\MBCP\Intune\AutoPilot\Logs\AutoPilot"
$LogFile = "C:\Programdata\MBCP\Intune\AutoPilot\Logs\BitLocker\PS_BitLocker.log"
$LogErr = "C:\Programdata\MBCP\Intune\AutoPilot\Logs\BitLocker\PS_BitLocker.nok"
$LogDir = "C:\Programdata\MBCP\Intune\AutoPilot\Logs\BitLocker"


CreateDir $LogDir
CreateDir $DirAuto

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now

# Variables
$scriptname = "Jedi_BitLocker"
$scriptversion = "1.00"
$logfile = "C:\Programdata\MBCP\Intune\AutoPilot\Logs\BitLocker\$scriptname.log"
$company  = "MillenniumBCP"
LogWrite "Starting script: '$scriptname' version: '$scriptversion'..."

#Check BitLocker prerequisites
$TPMNotEnabled = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm | where {$_.IsEnabled_InitialValue -eq $false} -ErrorAction SilentlyContinue
$TPMEnabled = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm | where {$_.IsEnabled_InitialValue -eq $true} -ErrorAction SilentlyContinue
$WindowsVer = Get-WmiObject -Query 'select * from Win32_OperatingSystem where (Version like "6.2%" or Version like "6.3%" or Version like "10.0%") and ProductType = "1"' -ErrorAction SilentlyContinue
$BitLockerReadyDrive = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
$BitLockerDecrypted = Get-BitLockerVolume -MountPoint $env:SystemDrive | where {$_.VolumeStatus -eq "FullyDecrypted"} -ErrorAction SilentlyContinue
$BLVS = Get-BitLockerVolume | Where-Object {$_.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}} -ErrorAction SilentlyContinue
$volumes = Get-BitLockerVolume

#Step 1 - autounlock
foreach ($item in $volumes)
{
    if ($item.AutoUnlockEnabled -eq $true)
    {
        $drive = $item.MountPoint
        LogWrite "Disable AutoUnlock on $drive"
        Disable-BitLockerAutoUnlock -MountPoint $item.MountPoint
    }
}

#Step 2 - Start Decrypting
foreach ($item in $volumes)
{
    if ($item.CapacityGB -ge 100)
    {  
        $BitLockerDecrypted = $true
        $BitLockerEncrypted = Get-BitLockerVolume -MountPoint $item.MountPoint | where {$_.VolumeStatus -ne "FullyDecrypted"} -ErrorAction SilentlyContinue        
        try
        {
            if ($BitLockerEncrypted)
            {
                $Msg = "Drive " + $item.MountPoint + " already encrypted"
                LogWrite $msg
                $BitLockerDecrypted = $false
            }
        }
        catch 
        {
            LogWrite "Error Decrypting"
            Write-host "$Error[0]"
            ForceErr
        }
    }    
}

if ($BitLockerDecrypted -eq $false)
{
    LogWrite "The drive is fully encrypted now :-), we are exiting the script !"  
    $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
    AutoPilot "End  " $now
    $intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
    Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
    Stop-Transcript
    exit 0    
}

#Step 3 - Check if TPM is enabled and initialise if required
LogWrite "Check if TPM is enabled and initialise if required"

try
{
    if ($WindowsVer -and !$TPMNotEnabled) 
    {
        LogWrite "TPM is starting to be initialise"
        Initialize-Tpm -AllowClear -AllowPhysicalPresence -ErrorAction SilentlyContinue
    }
    Else
    {
        LogWrite "TPM is initialise"
    }
}
catch
{
    LogWrite "Error initialising TPM"
    Write-host "$Error[0]"
    ForceErr
}

#Step 4 - Check if BitLocker volume is provisioned and partition system drive for BitLocker if required
LogWrite "Check if BitLocker volume is provisioned and partition system drive for BitLocker if required"
if ($WindowsVer -and $TPMEnabled -and !$BitLockerReadyDrive) 
{
    Get-Service -Name defragsvc -ErrorAction SilentlyContinue | Set-Service -Status Running -ErrorAction SilentlyContinue
    BdeHdCfg -target $env:SystemDrive shrink -quiet
}

#Step 5 - Check BitLocker AD Key backup Registry values exist and if not, create them.
LogWrite "Check BitLocker AD Key backup Registry values exist and if not, create them."

try
{
    $BitLockerRegLoc = 'HKLM:\SOFTWARE\Policies\Microsoft'
    if (Test-Path "$BitLockerRegLoc\FVE")
    {
        LogWrite '$BitLockerRegLoc\FVE Key already exists'        
        Remove-Item -Path "$BitLockerRegLoc\FVE"
        New-Item -Path "$BitLockerRegLoc" -Name 'FVE'
    }
    Else
    {
        LogWrite '$BitLockerRegLoc\FVE Key created'
        New-Item -Path "$BitLockerRegLoc" -Name 'FVE'
    }
}
catch
{
    LogWrite "Error getting registry Keys $BitLockerRegLoc\FVE"
    Write-host "$Error[0]"
    ForceErr
}

#Step 6 - If all prerequisites are met, then enable BitLocker
LogWrite "If all prerequisites are met, then enable BitLocker"
try
{
    if ($TPMEnabled) 
    {
        foreach ($item in $volumes)
        {
            if ($item.CapacityGB -ge 100)
            {
                $drive = $item.MountPoint

                LogWrite "Delete BitLocker Key Protector if exist"
                $keys = ((Get-BitLockerVolume -MountPoint $item.MountPoint).KeyProtector).KeyProtectorId
                if ($keys -ne $null)
                {
                    foreach ($item in $keys)
                    {
                        Remove-BitLockerKeyProtector -MountPoint $drive -KeyProtectorId $item -ErrorAction SilentlyContinue
                    }
                }
        
                LogWrite "Enable BitLocker"
                #$key = ((Get-BitLockerVolume).KeyProtector).KeyProtectorId

                if ($item.MountPoint -eq "C:")
                {
                    LogWrite "Add BitLocker Key Protector on $drive"
                    Add-BitLockerKeyProtector -MountPoint $item.MountPoint -TpmProtector                
                }

                LogWrite "Enable BitLocker on $drive"
                Enable-BitLocker -MountPoint $item.MountPoint -EncryptionMethod Aes256 -SkipHardwareTest -RecoveryPasswordProtector -UsedSpaceOnly -ErrorAction SilentlyContinue
	            #Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction SilentlyContinue

        
                # don't quit till fully encrypted
                do
                {
                    $BitLockerOSVolume = Get-BitLockerVolume -MountPoint $item.MountPoint
                    $percent =  $BitLockerOSVolume.EncryptionPercentage
                    LogWrite "Percentage Encrypted: '$percent'%."
                    Start-Sleep -Seconds 13            
                }

                until ($BitLockerOSVolume.EncryptionPercentage -eq 100)
            }

            if ($item.MountPoint -ne "C:")
            {
                $getstatus = Get-BitLockerVolume -MountPoint $item.MountPoint | where {$_.VolumeStatus -eq "FullyEncrypted"}
                if ($getstatus)
                {
                    write-host "!!!"
                    LogWrite "Enable BitLocker AutoUnlock on $drive"
                    Enable-BitLockerAutoUnlock -MountPoint $item.MountPoint  
                }
            }
        }
    }
}
catch
{
    LogWrite "Error enabling bitlocker"
    Write-host "$Error[0]"
    ForceErr
}


#Step 7 - add reg key confirming status
LogWrite "Add reg key confirming status"
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\$company\Intune\BitLocker" /V EncryptedDuringAutoPilot /T REG_DWORD /D 1 /F

LogWrite "The drive is fully encrypted now :-), we are exiting the script !"  
$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript

