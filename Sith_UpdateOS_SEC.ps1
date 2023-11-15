
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False)] [ValidateSet('Soft', 'Hard', 'None', 'Delayed')] [String] $Reboot = 'Delayed',
    [Parameter(Mandatory=$False)] [Int32] $RebootTimeout = 120
)

Process
{
cls
Remove-Variable * -ErrorAction SilentlyContinue

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }
}

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\UpdateOS"))
{
    Mkdir "C:\Windows\Temp\Logs\UpdateOS"
}


# Start logging
Start-Transcript "C:\Windows\Temp\Logs\UpdateOS\UpdateOS_SEC.log"
#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

# Main logic
$needReboot = $false
Write-Output $needReboot

# Load module from PowerShell Gallery
$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
Write-Output "$ts Importing NuGet and PSWindowsUpdate"
$null = Install-PackageProvider -Name NuGet -Force
$null = Install-Module PSWindowsUpdate -Force
Import-Module PSWindowsUpdate

# Install all available updates
$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
Write-Output "$ts Installing updates."

$GETUPDATES = Get-WindowsUpdate -AcceptAll -WindowsUpdate -UpdateType Software -IgnoreReboot
$CheckNumberUpdates = $GETUPDATES.Count
$UpdatetobeInstall = $GETUPDATES | select Title
Write-Output "Detect $CheckNumberUpdates Updates"
Write-Output $UpdatetobeInstall

$Reboot = 'None'
Write-Output $Reboot

foreach ($item in $GETUPDATES)
{
    #if ((($item.title).toupper() -like "*ETHERNET*") -or ($item.title).toupper() -like "*WIFI*" -OR ($item.title).toupper() -like "*WI-FI*")
    if (($item.title).toupper() -like "*BUSHBUSH*")
    {
        $updateid = $item.Title
        Write-Output "$updateid not installed"
    }
    Else
    {
        $updateid = $item.Title
        $updatereboot = $item.RebootRequired

        Write-Output "$updateid is installing"
        Write-Output $updatereboot
        if ($item.RebootRequired -EQ $True)
        {
            $Reboot = 'Soft'
            Write-Output "Change Reboot Variable to $Reboot"
        }
        Install-WindowsUpdate -WindowsUpdate -AcceptAll -IgnoreReboot -Verbose -UpdateID ($item.Identity).UpdateID  | Select Title, KB, Result | Format-Table
    }
}


# Specify return code
$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"

if ($Reboot -eq 'Soft' ) 
{
    Write-Output "$ts Windows Update indicated that a reboot is needed."
    Write-Output "$ts Exiting with return code 3010 to indicate a soft reboot is needed."
    $RebootCode = 3010
} 
else 
{
    Write-Output "$ts Windows Update indicated that no reboot is required."
    Write-Output "$ts Skipping reboot based on Reboot parameter (None)"
    $RebootCode = 0
}


try
{    
    $version = "0001"
    $VersionLocation = "HKLM:\SOFTWARE\MillenniumBCP\Intune\UpdateOS"


    if(-NOT (Test-Path $VersionLocation))
    { 
        if(-NOT(Test-Path "HKLM:\SOFTWARE\MillenniumBCP"))
        {
            New-Item "HKLM:\SOFTWARE" -Name "MillenniumBCP"
        }

        if(-NOT(Test-Path "HKLM:\SOFTWARE\MillenniumBCP\Intune"))
        {
            New-Item "HKLM:\SOFTWARE\MillenniumBCP" -Name "Intune"
        }

        if(-NOT(Test-Path "HKLM:\SOFTWARE\MillenniumBCP\Intune\UpdateOS"))
        {
            New-Item "HKLM:\SOFTWARE\MillenniumBCP\Intune" -Name "UpdateOS"
        }
    }

    Set-ItemProperty -Path $VersionLocation -Name "Security" -Value $version
}
catch
{
    Stop-Transcript
    exit 1
}

Stop-Transcript
Exit $RebootCode

}