cls
Remove-Variable * -ErrorAction SilentlyContinue



function ForceErr
{
    Stop-Transcript
    Rename-Item -Path $LogFile -NewName $LogErr
    
    if ((Test-Path $LogFile))
    {
        Remove-Item -Path $LogFile -Force
    }

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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\Eutils.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS.log"
$LogErr = "C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS.nok"
$LogDir = "C:\Windows\Temp\Logs\UpdateOS"


CreateDir $LogDir
CreateDir $DirAuto

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

Write-Host "Begin"

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now


# Main logic
$needReboot = $false

$checkVersion = (((Get-WmiObject -Class Win32_OperatingSystem).caption).split(" "))[2]
$searchVersion = "*Windows " + $checkVersion + " Version*"

$build = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion").DisplayVersion).toupper()
$searchbuild = "*" + $build + "*"

Write-Output $checkVersion
Write-Output $build
Write-Output $needReboot

try
{
    # Load module from PowerShell Gallery
    $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
    Write-Output "$ts Importing NuGet and PSWindowsUpdate"
    $null = Install-PackageProvider -Name NuGet -Force
    $null = Install-Module PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate
}
catch
{
    write-output "Error install PowerShell Module PSWindowsUpdate"
    ForceErr
}
# Install all available updates
$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
Write-Output "$ts Installing updates."
try
{
    $GETUPDATES = Get-WindowsUpdate -AcceptAll -WindowsUpdate -IgnoreReboot
    $CheckNumberUpdates = $GETUPDATES.Count
    $UpdatetobeInstall = $GETUPDATES | select Title
    Write-Output "Detect $CheckNumberUpdates Updates"
    Write-Output $UpdatetobeInstall

    $Reboot = 'None'
    Write-Output $Reboot
}
catch
{
    write-output "Error getting Updates"
    ForceErr
}

try
{
    foreach ($item in $GETUPDATES)
    {
        #if ((($item.title).toupper() -like "*ETHERNET*") -or ($item.title).toupper() -like "*WIFI*" -OR ($item.title).toupper() -like "*WI-FI*")
        if (($item.title).toupper() -notlike $searchbuild) 
        {
            if (($item.title).toupper() -notlike $searchVersion.ToUpper())           
            {
                if ((($item.title).toupper() -notlike "*BIOS*"))
                {
                    $updateid = $item.Title
                    $updatereboot = $item.RebootRequired
                    $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
                
                    Write-Output "$ts Start"
                    Write-Output "$updateid is installing"
                    Write-Output $updatereboot
                    if ($item.RebootRequired -EQ $True)
                    {
                        $Reboot = 'Soft'
                        Write-Output "Change Reboot Variable to $Reboot"
                    }
                    Install-WindowsUpdate -WindowsUpdate -AcceptAll -IgnoreReboot -Verbose -UpdateID ($item.Identity).UpdateID  | Select Title, KB, Result | Format-Table
                    Start-Sleep -Seconds 7
                }
            }
            Else
            {
                $updateid = $item.Title
                Write-Output "$updateid not installed"
            }
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
            Start-Sleep -Seconds 7
        }
    }
}
catch
{
    Write-Output "error install update $updateid"
    ForceErr
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
    $VersionLocation = "HKLM:\SOFTWARE\MillenniumBCP\Intune"


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
    }

    Set-ItemProperty -Path $VersionLocation -Name "WindowsUpdate" -Value $version
}
catch
{
    Write-Output "Erro creating registry mark"
    ForceErr
}


$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
Stop-Transcript

Exit $RebootCode