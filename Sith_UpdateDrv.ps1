Remove-Variable * -ErrorAction SilentlyContinue

$scriptVersion = "20250122"

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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\UpdateOS_DRV.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS_DRV.log"
$LogErr = "C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS_DRV.nok"
$LogDir = "C:\Windows\Temp\Logs\UpdateOS"


CreateDir $LogDir

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

Write-Host "Begin"
Write-Host $scriptVersion

try
{
    # Reset WindowsUpdate
    # Reset-WUComponents
    # Load module from PowerShell Gallery
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
    $GETUPDATES = Get-WindowsUpdate -AcceptAll -WindowsUpdate -UpdateType Driver -IgnoreReboot
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
    if ($CheckNumberUpdates -ne 0)
    {
        foreach ($item in $GETUPDATES)
        {      
            $updateid = $item.Title
            $updatereboot = $item.RebootRequired
            $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"               
            Write-Output "$ts Start"
            Write-Output "$updateid is installing"
            Write-Output $updatereboot
            if ($item.RebootRequired -EQ $True)
            {
                $Reboot = $true
                Write-Output "Change Reboot Variable to $Reboot"
            }
            Install-WindowsUpdate -WindowsUpdate -AcceptAll -IgnoreReboot -Verbose -UpdateID ($item.Identity).UpdateID -ErrorAction SilentlyContinue | Select Title, KB, Result | Format-Table
            Start-Sleep -Seconds 7
    }
    Else
    {
        write-host "No updates available"
    }
}
}
catch
{
    Write-Output "error install update $updateid"
    ForceErr
}


try
{    
    $version = "0003"
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

    Set-ItemProperty -Path $VersionLocation -Name "WindowsUpdateDriver" -Value $version
}
catch
{
    Write-Output "Erro creating registry mark"
    ForceErr
}


$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript

if ($CheckNumberUpdates -ne 0)
{   
    Exit 1641
}
else
{   
    Exit 0
}


