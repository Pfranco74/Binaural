
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}


Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
    )

    $TimeGenerated = $(Get-Date -UFormat "%D %T")
    $Line = "$TimeGenerated : $Message"
    Add-Content -Value $Line -Path $LogFile -Encoding Ascii
}

$logDirectory = "C:\Windows\Temp\Logs\AdminAccount"

if (-not (Test-Path $LogDirectory))
{
    Mkdir $LogDirectory
}

$LogFile = "C:\Windows\Temp\Logs\AdminAccount\Intune_ForceAdminAccount.log"
$logTranscript = "C:\Windows\Temp\Logs\AdminAccount\Transcript.log"
$user = "MADLENA" 
$defaultpassword = "1U1sP#CjhYC_L~p" | ConvertTo-SecureString -AsPlainText -Force
$Adminuser = $null


# Start logging
Start-Transcript $logTranscript

Write-Log "Search for administrator account" 

$UserLanguage = (Get-WinUserLanguageList)[0].languagetag
write-log "User language is $UserLanguage "

if ($UserLanguage.ToUpper() -eq "EN-US")
{
    $Adminuser = (Get-LocalUser -Name Administrator -ErrorAction SilentlyContinue ).name   
}

if ($UserLanguage.ToUpper() -eq "PT-PT")
{
    $Adminuser = (Get-LocalUser -Name Administrador -ErrorAction SilentlyContinue ).name    
}

if ($Adminuser -ne $null)
{
        Write-Log "Found User $Adminuser"  
        #wmic useraccount where name='Administrator' rename 'MADLENA'
        Write-Log "Try to Rename User"
        Rename-LocalUser -name $Adminuser -NewName $user        
        Write-Log "$Error[0]"     
}
Else
{
    Write-Log "User local admin not found"
    Write-Log "$Error[0]" 
    $checkmadlena = (Get-localuser -Name $user -ErrorAction SilentlyContinue)
    if (($checkuserstate.Name).ToUpper() -ne $user.ToUpper())
    {
        Write-Log "User MadLena admin not found"
        Stop-Transcript
        exit 1
    }
    
}


Write-Log "Verify MADLENA Account"

$checkuserstate = (Get-localuser -Name $user).Enabled

Write-Log "Verify MADLENA is enable"


if($checkuserstate -eq $false)
{
    Write-Log "MADLENA Exist - Disable "  
    try
    {
        $UserAccount = Get-LocalUser -Name $user
        Write-Log "$user Set Default Password" 	    
        Get-LocalUser -name $user | Set-LocalUser -PasswordNeverExpires:$false -password $defaultpassword	    
        Write-Log "Try to set $user Enabled" 
        Enable-LocalUser -Name $user        
	    Invoke-LapsPolicyProcessing
        Stop-Transcript
        Exit 0
    }
    Catch
    {
        Write-Log "Catch Error"
        Write-Log "$Error[0]"
        Invoke-LapsPolicyProcessing
        Write-Log "$Error[0]" 
        Stop-Transcript
        Exit 1
    }
}
Else
{
    Write-Log "$user is already Enabled"
    Invoke-LapsPolicyProcessing
    Write-Log "$Error[0]"
    Stop-Transcript 
    Exit 0
}