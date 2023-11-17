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
    Rename-Item -Path "C:\Windows\Temp\Logs\BitLocker\BitLocker.log" -NewName "C:\Windows\Temp\Logs\BitLocker\BitLocker.NOK"
    
    if ((Test-Path "C:\Windows\Temp\Logs\BitLocker\BitLocker.log"))
    {
        Remove-Item -Path "C:\Windows\Temp\Logs\BitLocker\BitLocker.log" -Force
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

Start-Transcript "C:\Windows\Temp\Logs\BitLocker\BitLocker.log"

# Variables
$scriptname = "Sith_BitLocker"
$scriptversion = "1.00"
$logfile = "C:\Windows\Temp\Logs\BitLocker\$scriptname.log"
$company  = "MillenniumBCP"
LogWrite "Starting script: '$scriptname' version: '$scriptversion'..."

#Check BitLocker prerequisites
$TPMNotEnabled = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm | where {$_.IsEnabled_InitialValue -eq $false} -ErrorAction SilentlyContinue
$TPMEnabled = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm | where {$_.IsEnabled_InitialValue -eq $true} -ErrorAction SilentlyContinue
$WindowsVer = Get-WmiObject -Query 'select * from Win32_OperatingSystem where (Version like "6.2%" or Version like "6.3%" or Version like "10.0%") and ProductType = "1"' -ErrorAction SilentlyContinue
$BitLockerReadyDrive = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
$BitLockerDecrypted = Get-BitLockerVolume -MountPoint $env:SystemDrive | where {$_.VolumeStatus -eq "FullyDecrypted"} -ErrorAction SilentlyContinue
$BLVS = Get-BitLockerVolume | Where-Object {$_.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}} -ErrorAction SilentlyContinue
$BitLockerEncrypted = Get-BitLockerVolume -MountPoint $env:SystemDrive | where {$_.VolumeStatus -ne "FullyDecrypted"} -ErrorAction SilentlyContinue


#start Decrypting
if ($BitLockerEncrypted)
{
    LogWrite "Start Decryting"
    Disable-BitLocker -MountPoint $env:SystemDrive -Confirm:$false 

    # don't quit till fully encrypted
    do
    {
        $BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
        $percent =  $BitLockerOSVolume.EncryptionPercentage
        LogWrite "Percentage Encrypted: '$percent'%."
        Start-Sleep -Seconds 13            
    }
    
    until ($BitLockerOSVolume.EncryptionPercentage -eq 0)
    $BitLockerDecrypted = Get-BitLockerVolume -MountPoint $env:SystemDrive | where {$_.VolumeStatus -eq "FullyDecrypted"} -ErrorAction SilentlyContinue
}



#Step 0 - Copy files
$TempDirectory = "C:\Windows\Temp\BitLocker"
if (-not(Test-Path -Path $TempDirectory))
{
    New-Item -Path $TempDirectory -ItemType Directory
}

LogWrite "Copy Files to $TempDirectory"
try
{
    # Copy the Reg files
    Copy-Item ".\files\*" $TempDirectory
}
catch 
{
    ForceErr
}


#Step 1 - Check if TPM is enabled and initialise if required
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
    ForceErr
}

#Step 2 - Check if BitLocker volume is provisioned and partition system drive for BitLocker if required
LogWrite "Check if BitLocker volume is provisioned and partition system drive for BitLocker if required"
if ($WindowsVer -and $TPMEnabled -and !$BitLockerReadyDrive) 
{
    Get-Service -Name defragsvc -ErrorAction SilentlyContinue | Set-Service -Status Running -ErrorAction SilentlyContinue
    BdeHdCfg -target $env:SystemDrive shrink -quiet
}

#Step 3 - Check BitLocker AD Key backup Registry values exist and if not, create them.
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
    ForceErr
}

#Step 4 - If all prerequisites are met, then enable BitLocker
LogWrite "If all prerequisites are met, then enable BitLocker"
try
{
    if ($WindowsVer -and $TPMEnabled -and $BitLockerReadyDrive -and $BitLockerDecrypted) 
    {
        LogWrite "Delete BitLocker Key Protector if exist"
        $keys = ((Get-BitLockerVolume).KeyProtector).KeyProtectorId
        if ($keys -ne $null)
        {
            foreach ($item in $keys)
            {
                Remove-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $item
            }
        }
        LogWrite "Add BitLocker Key Protector"
        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector
        LogWrite "Enable BitLocker"
        #$key = ((Get-BitLockerVolume).KeyProtector).KeyProtectorId
        Enable-BitLocker -MountPoint $env:SystemDrive -EncryptionMethod Aes256 -SkipHardwareTest -RecoveryPasswordProtector -UsedSpaceOnly -ErrorAction SilentlyContinue
	    #Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction SilentlyContinue

        
        # don't quit till fully encrypted
        do
        {
            $BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
            $percent =  $BitLockerOSVolume.EncryptionPercentage
            LogWrite "Percentage Encrypted: '$percent'%."
            Start-Sleep -Seconds 13            
        }

        until ($BitLockerOSVolume.EncryptionPercentage -eq 100)
    }
}
catch
{
    LogWrite "Error enabling bitlocker"
    ForceErr
}

#Create Schedule Task for logon to ad"
LogWrite "Create Schedule Task for logon to ad"
$List = Get-ChildItem -Path $TempDirectory -Filter *.xml

foreach ($item in $list)
{
    try
    {
        $Name = ($item.Name).Split(".")[0]
        write-host $Name
        Register-ScheduledTask -xml (Get-Content $item.FullName | Out-String) -TaskName $Name -TaskPath "\" -Force
        #Get-ScheduledTask -TaskName $Name | Disable-ScheduledTask$Name
    }
    catch
    {
        Stop-Transcript
        exit 1
    }
}

# add reg key confirming status
LogWrite "Add reg key confirming status"
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\$company\Intune\BitLocker" /V EncryptedDuringAutoPilot /T REG_DWORD /D 1 /F

LogWrite "The drive is fully encrypted now :-), we are exiting the script !"  
Stop-Transcript