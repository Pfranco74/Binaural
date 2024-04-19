cls
Remove-Variable * -ErrorAction SilentlyContinue

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

#Create a log folder
if (-not (Test-Path "C:\Windows\Temp\Logs\BitLocker"))
{
    Mkdir "C:\Windows\Temp\Logs\BitLocker"
}

function ForceErr
{
    Stop-Transcript
    Rename-Item -Path "C:\Windows\Temp\Logs\BitLocker\BitLockerBakcup.log" -NewName "C:\Windows\Temp\Logs\BitLocker\BitLockerBakcup.NOK"
    
    if ((Test-Path "C:\Windows\Temp\Logs\BitLocker\BitLockerBakcup.log"))
    {
        Remove-Item -Path "C:\Windows\Temp\Logs\BitLocker\BitLockerBakcup.log" -Force
    }

    exit 13    
}

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

Start-Transcript "C:\Windows\Temp\Logs\BitLocker\BitLockerBackup.log"


# Variables
$scriptname = "Sith_BitLockerBackup"
$scriptversion = "1.00"
$logfile = "C:\Windows\Temp\Logs\BitLocker\$scriptname.log"
$company  = "MillenniumBCP"
LogWrite "Starting script: '$scriptname' version: '$scriptversion'..."

LogWrite "Search on event viewer for BitLocker backup on AD Success"
$BitLockerEvents = Get-WinEvent -LogName "Microsoft-Windows-BitLocker/BitLocker Management"

foreach ($item in $BitLockerEvents)
{
    if ($item.id -eq 845)
    {
        LogWrite "Found Event Nothing to do"
        Get-ScheduledTask -TaskName "Enable BitLocker Backup" | Unregister-ScheduledTask -Confirm:$false
        Remove-Item -Path C:\Windows\temp\BitLocker\Sith_BitLockerBackup.ps1 -force
        Remove-Item -Path 'C:\Windows\Temp\BitLocker\Enable BitLocker Backup.xml' -force
        Stop-Transcript
        exit 0
    }
}




#Step 3 - Check BitLocker AD Key backup Registry values exist and if not, create them.
LogWrite "Check BitLocker AD Key backup Registry values exist and if not, create them."
try
{
    $BitLockerRegLoc = 'HKLM:\SOFTWARE\Policies\Microsoft'
    if (Test-Path "$BitLockerRegLoc\FVE")
    {
        LogWrite '$BitLockerRegLoc\FVE Key already exists'
    }
    Else
    {
        LogWrite '$BitLockerRegLoc\FVE Key created'
        New-Item -Path "$BitLockerRegLoc" -Name 'FVE'
    }
    LogWrite "Create BitLocker Policies"
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'ActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'EnableBDEWithNoTPM' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'EncryptionMethodWithXtsFdv' -Value '00000007' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'EncryptionMethodWithXtsOs' -Value '00000007' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'EncryptionMethodWithXtsRdv' -Value '00000007' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVActiveDirectoryInfoToStore' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVEncryptionType' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVHideRecoveryPage' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVManageDRA' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRecovery' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRecoveryKey' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRecoveryPassword' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRequireActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'MinimumPIN' -Value '00000006' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSActiveDirectoryInfoToStore' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSEncryptionType' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSHideRecoveryPage' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSManageDRA' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSRecovery' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSRecoveryKey' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSRecoveryPassword' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSRequireActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RDVAllowBDE' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RDVConfigureBDE' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RDVDenyCrossOrg' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RDVDisableBDE' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RDVEncryptionType' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RequireActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'UseAdvancedStartup' -Value '00000001' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'UseTPM' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'UseTPMKey' -Value '00000002' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'UseTPMKeyPIN' -Value '00000000' -PropertyType DWORD -Force
    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'UseTPMPIN' -Value '00000000' -PropertyType DWORD -Force
    }
catch
{
    LogWrite "Error getting registry Keys $BitLockerRegLoc\FVE"
    ForceErr
}


#Step  - Backup BitLocker recovery passwords to AD
LogWrite "Backup BitLocker recovery passwords to AD"
$BLVS = Get-BitLockerVolume | Where-Object {$_.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}} -ErrorAction SilentlyContinue

if ($BLVS) 
{
    ForEach ($BLV in $BLVS) 
    {
        $Key = $BLV | Select-Object -ExpandProperty KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
        ForEach ($obj in $key)
        { 
            BackupToAAD-BitLockerKeyProtector -MountPoint $BLV.MountPoint -KeyProtectorID $obj.KeyProtectorId

        }
    }
}
Stop-Transcript

