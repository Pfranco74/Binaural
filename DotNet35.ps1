# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "C:\Windows\Temp\Logs\DotNet35"))
{
    Mkdir "C:\Windows\Temp\Logs\DotNet35"
}

# Start logging
Start-Transcript "C:\Windows\Temp\Logs\DotNet35\DotNet35.log"
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'

$Version = (((Get-WmiObject -Class Win32_OperatingSystem).caption).split(" "))[2]
Write-Host "Windows Version $Version"
$build = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion").DisplayVersion).toupper()
Write-Host "Windows Build $build"

$dotnetpackage = ".\Files\Win" + $Version

# Check Package
if (-not (Test-Path $dotnetpackage))
{
    write-host "Package not found"
    Stop-Transcript
    exit 1
}


# Temp Folder
$TempDirectory = "c:\Windows\Temp\DotNet35"
if (-not (Test-Path "c:\Windows\Temp\DotNet35"))
{
    Mkdir "c:\Windows\Temp\DotNet35"
}

try
{
    # Copy the Reg files
    Copy-Item $dotnetpackage\* $TempDirectory
}
catch 
{
    Stop-Transcript
    exit 1
}

$CabDir = "c:\Windows\Temp\DotNet35\*.cab"
$Cab = Get-ChildItem -Path $CabDir -File
try
{
    foreach ($item in $Cab)
    {
        
        $Cabname = $item.FullName

        Add-WindowsPackage -Online -PackagePath $Cabname -NoRestart -IgnoreCheck -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 
    }

    Add-WindowsCapability -Online -Name NetFX3~~~~
}
catch
{
    Add-WindowsCapability -Online -Name NetFX3~~~~
}

if ((Test-Path -Path $TempDirectory))
{
   Remove-Item -Path $TempDirectory -Force -Recurse
}

Stop-Transcript
