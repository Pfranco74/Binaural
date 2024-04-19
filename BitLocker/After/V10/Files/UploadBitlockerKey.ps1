<#
.SYNOPSIS
	This script is to rotate the bitlocker recovery key AFTER successfully enabling bitlocker during pre-provisioning with WhiteGlove
.DESCRIPTION
	The script is provided as required Win32 app. Execution via Intune is in SYSTEM context.
.PARAMETER [none]
	This script does not take any parameters.
.EXAMPLE
	win.ap.upload.bitlocker.key.after.whiteglove.ps1
.NOTES
    Version: 0.01 2023/01/30 script creation
    Version: 0.02 2023/01/31 bug fixing..
    Version: 0.03 2023/02/01 upload to Azure
    Version: 0.04 2023/02/01 fixing bugs with adding RK
    Version: 0.05 2023/02/01 improve logging to make it easier to troubleshoot
    Version: 0.06 2023/02/06 adding task removal
    Version: 0.07 2023/02/08 shutdown code added
    Version: 0.08 2023/02/08 comment added to shutdown code
    Version: 0.09 2023/02/08 remove user from local admins group
    Version: 0.10 2023/02/09 trying alt method to remove local admin.
    Version: 0.11 2023/02/09 add defaultuser0 check
    Version: 0.12 2023/02/10 change the order of events after successful key upload
    Version: 0.13 2023/02/20 renamed script from rotate to upload
    Version: 0.14 2023/03/02 add scheduled task to trigger intune sync on successful key upload, and add a reg key

.LINK 
	.Author Niall Brady 2023/01/30
#>

# The script flow is as follows;
#
# add recovery password protector
# remove BEK protector
# upload the bitlocker recovery key, needed ? nope.
# if successful then create a scheduled task
#

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

Function AddRecoveryPassword{
# add recovery password
    try {
        Logwrite "adding recovery password..."
        #$cmdOutput = & manage-bde -protectors -add c: -RecoveryPassword
        $command = "$env:systemroot\System32\manage-bde.exe"
        $parms = " -protectors -add c: -RecoveryPassword"
        Start-process -NoNewWindow -Wait -FilePath $command -argumentlist $parms
        # -RedirectStandardOutput $logfile
        Logwrite "succeeded adding protector !"}
catch [System.Exception] {Logwrite "failed to add protector !" -fail}
logwrite $cmdOutput}

Function RemoveProtector{
# remove the BEK method..

# via https://learn.microsoft.com/en-us/powershell/module/bitlocker/remove-bitlockerkeyprotector?view=windowsserver2022-ps
LogWrite "removing BEK protector"
$BLV = Get-BitLockerVolume -MountPoint "C:"
Logwrite "DEBUG: BLV = '$BLV'"
try {
    Logwrite "attempting to remove protector..."
    Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $BLV.KeyProtector[1].KeyProtectorId
    Logwrite "succeeded removing protector!"
    $BLV = Get-BitLockerVolume -MountPoint "C:"
    Logwrite "DEBUG: BLV = '$BLV'"
}
catch [System.Exception] {Logwrite "Failed to remove the BEK protector!" -fail
    $BLV = Get-BitLockerVolume -MountPoint "C:"
    Logwrite "DEBUG: BLV = '$BLV'"}
}

Function Rotate{
$MountPoint = "C:"
$KeyProtectors = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector
foreach($KeyProtector in $KeyProtectors){
    if($KeyProtector.KeyProtectorType -eq "RecoveryPassword"){
        try{
            Remove-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $KeyProtector.KeyProtectorId | Out-Null
            Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector -WarningAction SilentlyContinue | Out-Null
            # If we get this far, eveything has worked, write a success to the event log
            LogWrite "Successfully rotated BitLocker Recovery Password"
        }
        catch{
            $Error[0]
            LogWrite "Failed to change Bitlocker Recovery Password for $MountPoint"
        }
    }
}}

Function Debug {
#For debugging, show all active protectors
LogWrite "DEBUG: show all active protectors..."
$cmdOutput = & manage-bde -protectors -get c:   # captures the command's success stream / stdout output
LogWrite $cmdOutput
}

Function RemoveScheduledTask($TaskName) {
 try {
    LogWrite "About to delete scheduled task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop | Out-Null
    LogWrite "Succeeded to remove scheduled task: $TaskName"
    return $true
    }

catch {
    LogWrite "Failed to delete scheduled task: $TaskName"
    return $false
    }   
}

Function CheckLoggedOnUser {
LogWrite "Checking logged on user to determine if we are still in the ESP or not."
$usernames = @('defaultuser0','defaultuser1')
$currentuser = (Get-Process -IncludeUserName -Name explorer | Select-Object -ExpandProperty UserName).Split('\')[1] 
#$currentuser = "defaultuser1"
if ($usernames -notcontains $currentuser) {  
    LogWrite "Not in ESP, will continue!" } else {
    LogWrite "In ESP, will not run!"
    exit 0
} }

# 
$scriptname = "win.ap.upload.bitlocker.key.after.whiteglove"
$scriptversion = "0.14"
$logfile = "$env:temp\$scriptname.log"
$company = "windows-noob"

LogWrite "Starting script: '$scriptname' version: '$scriptversion'..."

CheckLoggedOnUser

#Debug

Logwrite "Removing BEK..."
RemoveProtector

#Debug

LogWrite "Adding RK..."
AddRecoveryPassword

#Debug

#Logwrite "about to rotate the key..."
#Rotate

$uploaded = $false

try {
$BLV = Get-BitLockerVolume -MountPoint "C:" | select *
[array]$ID = ($BLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId
Logwrite "about to upload key to Azure"
BackupToAAD-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $ID[0]
Logwrite "succeeded to upload the BitLocker recovery key to Azure !"
$uploaded = $true

    ###################################################################################################
    # 
    # if we successfully uploaded the key, let's do some remaining actions...namely...
    #
    # remove the user from the Local Administrators group
    # remove the Scheduled Task
    # restart the computer so that Bitlocker Compliance is quicker
    #
    if($uploaded){  
    
        ###################################################################################################     
        # remove user from local admins group
        $localUserFull = Get-CimInstance -ClassName Win32_ComputerSystem | select -ExpandProperty UserName

                                    try {Logwrite "removing user '$localUserFull' from Local Admins group"
                $user = $localUserFull;
                $group = "Administrators";
                # $groupObj =[ADSI]"WinNT://./$group,group" 
                # $userObj = [ADSI]"WinNT://$user,user"
                # $groupObj.Remove($userObj.Path)
                net localgroup $group /delete $localUserFull
                LogWrite "succeeded to remove the user from the group"}
               catch [System.Exception] {Logwrite "failed to remove the user from the local admins group !" -fail
               }

        ###################################################################################################
        # remove scheduled task
        LogWrite "about to remove the Scheduled task"
        $taskName = "Win.AP.WhiteGlove.UploadBitLockerKeyToIntune"
        $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }

   if($taskExists) {

                     try {
                        # DELETE it so it never runs again
                        LogWrite "Info: The '$taskName' scheduled task exists, removing the scheduled task..."
                        RemoveScheduledTask $taskName
                        LogWrite "succeeded removing the '$taskName' scheduled task !"
                        }
                 catch [System.Exception]{ Logwrite "failed to delete the scheduled task !" -fail
                 Logwrite "exiting script, could not delete the scheduled task, see error message..."
                 exit 0}
    }
   ###################################################################################################                       
   # ok we've succeeded in removing the scheduled task, now let's do the last actions, 
   ###################################################################################################

   # add reg key confirming key upload status
    LogWrite "adding reg key to confirm key upload status"
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\$company\WhiteGlove" /V KeyUploadedAfterWhiteGlove /T REG_DWORD /D 1 /F
   # Create a RunOnce reg key to trigger an Intune sync to speed up compliance on the next login
    LogWrite "Creating a RunOnce reg key to trigger intune sync"
    try {
        #Get-ScheduledTask | ? {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask  
        reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v TriggerSync /t REG_SZ /d "C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe -noprofile -sta -WindowStyle Hidden -Command Get-ScheduledTask | ? {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask"   
        LogWrite "succeeded to create the RunOnce registry key"}
    catch [System.Exception] {Logwrite "failed to create the RunOnce registry key!" -fail}
   ###################################################################################################
   #schedule a mandatory restart (for compliance)
   #
                try {
                        Logwrite "doing a mandatory shutdown/restart..."
                        $command = "$env:systemroot\System32\shutdown.exe"
                        $parms = " /r /t 5 /c `"We must restart the computer to become compliant with $company security policies. Thank you for your patience.`""
                        Start-process -NoNewWindow -FilePath $command -argumentlist $parms
                        # -RedirectStandardOutput $logfile
                        Logwrite "succeeded to issue the shutdown command, will restart in 5 seconds!"}
                catch [System.Exception] {Logwrite "failed to issue the shutdown command !" -fail
                logwrite $command}
                }
    #
    #
   
}
catch [System.Exception] {Logwrite "Failed to upload the key !!, therefore we will rerun this script again later...." -fail
exit 0}


Logwrite "script completed..."
exit 3010
