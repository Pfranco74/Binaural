<#
.SYNOPSIS
	This script is to enable bitlocker encryption during the Windows Autopilot while pre-provisioning with WhiteGlove
.DESCRIPTION
	The script should be deployed to WhiteGlove devices in SYSTEM context.
.PARAMETER [none]
	This script does not take any parameters.
.EXAMPLE
	win.ap.enable.bitlocker.during.whiteglove.ps1
.NOTES
	Version: 0.01 2023/01/26
    Version: 0.02 2023/01/27 some more logging, change from enable-bitlocker to manage-bde and added a drive letter to the SYSTEM partition
    Version: 0.03 2023/01/28 launching manage-bde as a cmd
    Version: 0.04 2023/01/28 remove drive letter after storing rk
    Version: 0.05 redirectstandardoutput 
    Version: 0.06 2023/01/30 add 15 seconds before starting bl and move the drive letter removal to the end of the script
    Version: 0.07 2023/01/30 added new logging including scriptname and version
    Version: 0.08 2023/01/30 alt method
    Version: 0.09 2023/01/30
    Version: 0.10 2023/01/30 bek method and rk method added
    Version: 0.11 2023/02/26 cleanup before documentation and release

.LINK 
	.Author Niall Brady 2023/01/26
#>

# The script flow is as follows
#
# eject any CD's (not implemented in this script)
# locate SYSTEM partition (efi/fat32)
# assign drive letter D: to the SYSTEM partition
# enable bitlocker using the following command...
#
# Manage-bde -on C: -recoverypassword > d:\recoverypassword.txt 
# using bits from https://raw.githubusercontent.com/brookspeppin/Blogs/main/3%20Things%20to%20Know%20Before%20Deploying%20BitLocker%20with%20Intune/Enable-BitLocker.ps1
# after encryption is complete, write a reg key so other apps will know we are done
#

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

 #Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\BitLocker"))
{
Mkdir "C:\Windows\Temp\Logs\BitLocker"
}

# Create Folders
$TempDirectory = "C:\Windows\Temp\FVE"
if (-not(Test-Path -Path $TempDirectory))
{
    New-Item -Path $TempDirectory -ItemType Directory
}

# writes to screen and log file
Function LogWrite{
	Param ([string]$logstring)
	$a = Get-Date
	$logstring = $a,$logstring
	Try{   
		Add-content $Logfile -value $logstring -ErrorAction silentlycontinue
	}Catch{

		$logstring="Invalid data encountered"
		Add-content $Logfile -value $logstring
	}
	write-host $logstring
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

Start-Transcript "C:\Windows\Temp\Logs\BitLocker\BitLocker.log"
Write-Host "Begin"

try
{
    # Copy the Reg files
    Copy-Item ".\files\*" $TempDirectory
}
catch 
{
    ForceErr
}

# Get Reg Files
$List = Get-ChildItem -Path $TempDirectory -filter "*.reg"

# Process List of Reg Files
foreach ($item in $list)
{
    try
    {
        $Name = ($item.Name).Split(".")[0]
        $Command = "c:\windows\regedit.exe"
        $parm = "/S " + $item.FullName
        # $run = (Start-Process $Command -ArgumentList $parm -Wait -PassThru)
    }
    catch
    {
        ForceErr
    }
}

# 
$scriptname = "Sith_BitLocker"
$scriptversion = "1.00"
$logfile = "C:\Windows\Temp\Logs\BitLocker\$scriptname.log"
$company  = "MillenniumBCP"
LogWrite "Starting script: '$scriptname' version: '$scriptversion'..."

LogWrite "checking the current bitlocker encryption status" 
# bitlocker checks

$BLinfo = Get-Bitlockervolume -MountPoint $env:systemdrive | Select *

Logwrite "Current Bitlocker Status: $(@($blinfo.VolumeStatus)), $(@($blinfo.EncryptionMethod))"

$a = $blinfo.VolumeStatus
$b = $blinfo.EncryptionMethod

if ([string]$a -contains 'FullyDecrypted')
{
LogWrite "Fully decrypted, no need to decrypt"
}

if ([string]$b -ne 'None') {
LogWrite "Encrypted already, let's exit out of this..."
# add reg key confirming status 
    try
    {
        LogWrite "adding a REG key to show already encrypted"
        REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\$company\Intune\BitLocker" /V AlreadyEncrypted /T REG_DWORD /D 1 /F
        Stop-Transcript
        exit 0
    }
    catch [System.Exception] 
    {
        LogWrite "Ran into an issue while adding the reg key: '$PSItem'"  -fail
        ForceErr
    }
}

Logwrite "starting TPM section"

try {

    # Check if TPM chip is currently owned, if not take ownership

    $TPMClass = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTPM" -Class "Win32_TPM"

    $IsTPMOwned = $TPMClass.IsOwned().IsOwned

    if ($IsTPMOwned -eq $false) {

        LogWrite "TPM chip is currently not owned, value from WMI class method 'IsOwned' was: $($IsTPMOwned)"

        # Generate a random pass phrase to be used when taking ownership of TPM chip
        $NewPassPhrase = (New-Guid).Guid.Replace("-", "").SubString(0, 14)


        # Construct owner auth encoded string
        $NewOwnerAuth = $TPMClass.ConvertToOwnerAuth($NewPassPhrase).OwnerAuth

        # Attempt to take ownership of TPM chip
        $Invocation = $TPMClass.TakeOwnership($NewOwnerAuth)

        if ($Invocation.ReturnValue -eq 0) {
        LogWrite  "TPM chip ownership was successfully taken"
        }

        else {
        LogWrite "Failed to take ownership of TPM chip, return value from invocation: $($Invocation.ReturnValue)"
        }

    }

    else {
        LogWrite "TPM chip is currently owned, will not attempt to take ownership"
    }

}

catch [System.Exception] 
{
    LogWrite "Ran into an issue: '$PSItem'"  -fail
    ForceErr
}

$driveletter = "N"

try 
{
    LogWrite "attempting to assign drive letter to the SYSTEM partition"
    get-partition | where-object {$_.GptType -eq "{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}"} | Set-Partition -NewDriveLetter $driveletter
}
catch [System.Exception] 
{
    LogWrite "failed adding drive letter to the SYSTEM partition: '$PSItem'"  -fail
    ForceErr
}


LogWrite "starting BitLocker Encryption section"

try {
    #This ensures that the correct encryption type is also set in the registry. The Intune BitLocker profile will also set this same key. 

    try 
    {
        LogWrite "adding reg keys for BitLocker encryption settings"
        $BitLockerRegLoc = 'HKLM:\SOFTWARE\Policies\Microsoft'
	    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'ActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
        New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'EncryptionMethodWithXtsOs' -Value '00000007' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRecovery' -Value '00000001' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVManageDRA' -Value '00000000' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRecoveryPassword' -Value '00000002' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRecoveryKey' -Value '00000002' -PropertyType DWORD -Force
	    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVRequireActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'FDVActiveDirectoryInfoToStore' -Value '00000002' -PropertyType DWORD -Force
	    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSAllowedHardwareEncryptionAlgorithms' -Value '00000000' -PropertyType DWORD -Force
        #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSRequireActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSRecovery' -Value '00000002' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSManageDRA' -Value '00000000' -PropertyType DWORD -Force
	    New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
	    #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'OSActiveDirectoryInfoToStore' -Value '00000002' -PropertyType DWORD -Force
        #New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name 'RequireActiveDirectoryBackup' -Value '00000001' -PropertyType DWORD -Force
        LogWrite "succeeded adding the reg key"
    }
    catch [System.Exception]
    {
        LogWrite "Ran into an issue while adding the reg key: '$PSItem'"  -fail
        ForceErr
    }

    try 
    {
        LogWrite "Enabling BitLocker, TPM Protector and Recovery Password Protector"
         # RK method
        Enable-BitLocker -MountPoint $env:SystemDrive -UsedSpaceOnly -SkipHardwareTest -RecoveryKeyPath "$driveletter`:\" -RecoveryKeyProtector
        # BEK method 
         #Get-BitLockerVolume | Enable-BitLocker -UsedSpaceOnly -SkipHardwareTest -RecoveryKeyPath "$driveletter`:\" -RecoveryKeyProtector
        sleep 15        LogWrite "enabling bitlocker worked YAY!!!!"     }
    catch [System.Exception] 
    {
        LogWrite "FAILED to enable BitLocker: '$PSItem'"  -fail
        LogWrite "Please do verify that you don't have an active Endpoint Protection policy targeted to this computer with BitLocker settings as it will cause this to fail!"
        # remove drive letter !
        LogWrite "removing driveletter..."
        Get-Volume -Drive $DriveLetter | Get-Partition | Remove-PartitionAccessPath -accesspath "$driveletter`:\" 
        ForceErr
    }

    sleep 5

    $BLinfo = Get-Bitlockervolume -MountPoint $env:systemdrive | Select *
    LogWrite "Current BL Status: $(@($blinfo.MountPoint)), $(@($blinfo.VolumeStatus)), $(@($blinfo.EncryptionMethod)),$(@($blinfo.KeyProtector))"
}

catch 
{

    LogWrite "Ran into an issue: $PSItem"  -fail
    ForceErr
}

# don't quit till fully encrypted

 do {
        $BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
        $percent =  $BitLockerOSVolume.EncryptionPercentage
        LogWrite "Percentage Encrypted: '$percent'%." 
    }

until ($BitLockerOSVolume.EncryptionPercentage -eq 100)

    
$BLinfo = Get-Bitlockervolume -MountPoint $env:systemdrive | Select *

LogWrite "Current BL Status: $(@($blinfo.MountPoint)), $(@($blinfo.VolumeStatus)), $(@($blinfo.EncryptionMethod)),$(@($blinfo.KeyProtector))"

# add reg key confirming status
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\$company\Intune\BitLocker" /V EncryptedDuringAutoPilot /T REG_DWORD /D 1 /F
    
    
# remove drive letter !
LogWrite "removing drive letter assigned to the SYSTEM partition now..."
Get-Volume -Drive $DriveLetter | Get-Partition | Remove-PartitionAccessPath -accesspath "$driveletter`:\" 
    
#LogWrite "The drive is fully encrypted now :-), we are issuing a restart so Intune will hopefully become aware of the Bitlocker compliance, after the restart we'll exit the script !"  

LogWrite "The drive is fully encrypted now :-), we are exiting the script !"  

if ((Test-Path -Path $TempDirectory))
{
    Remove-Item -Path $TempDirectory -Force -Recurse
}

Write-Host "End"
Stop-Transcript