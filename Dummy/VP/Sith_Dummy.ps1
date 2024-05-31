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
if (-not (Test-Path "$($env:ProgramData)\Microsoft\Dummy"))
{
    Mkdir "$($env:ProgramData)\Microsoft\Dummy"
}



$TempDirectory = "C:\Windows\Temp\PS1"
# Create Folders
if (-not(Test-Path -Path $TempDirectory))
{
    New-Item -Path $TempDirectory -ItemType Directory
}

# Start logging
Start-Transcript "$($env:ProgramData)\Microsoft\Dummy\Dummy.log"
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'

try
{
    # Copy the Reg files
    Copy-Item ".\files\*" $TempDirectory
}
catch 
{
    exit 1
}


try
{    
    $version = "0001"
    $VersionLocation = "HKCU:\SOFTWARE\Millenniumbcp\Intune"


    if(-NOT (Test-Path $VersionLocation))
    { 
        if(-NOT(Test-Path  "HKCU:\SOFTWARE\MillenniumBCP"))
        {
            New-Item "HKCU:\SOFTWARE" -Name "MillenniumBCP"
        }
        New-Item -Path "HKCU:\SOFTWARE\Millenniumbcp" -Name "Intune"
    }

    Set-ItemProperty -Path $VersionLocation -Name "Dummy" -Value $version
}
catch
{
    Stop-Transcript
    exit 1
}

try
{    
    $version = "0001"
    $VersionLocation = "HKLM:\SOFTWARE\Millenniumbcp\Intune"


    if(-NOT (Test-Path $VersionLocation))
    { 
        if(-NOT(Test-Path  "HKLM:\SOFTWARE\MillenniumBCP"))
        {
            New-Item "HKLM:\SOFTWARE" -Name "MillenniumBCP"
        }
        New-Item -Path "HKLM:\SOFTWARE\Millenniumbcp" -Name "Intune"
    }

    Set-ItemProperty -Path $VersionLocation -Name "Dummy" -Value $version
}
catch
{
    Stop-Transcript
    exit 1
}

Stop-Transcript
