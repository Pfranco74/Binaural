$scriptVersion = "20250122"

Remove-Variable * -ErrorAction SilentlyContinue

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

function Manufacturer
{
$Manufacturer = ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer).toupper()

if ($Manufacturer -eq 'HEWLETT-PACKARD')
{
$Manufacturer = 'HP'
}

write-host $Manufacturer -ForegroundColor Green

Return $Manufacturer
}

function ComputerModel
{

    # Get Model
    $Model = (Get-CimInstance -ClassName CIM_ComputerSystem -ErrorAction SilentlyContinue -Verbose:$false).Model
    $Model = $Model.Trim()

    if ($Model.Length -gt 5) 
    {
        $Model = $Model.Substring(0, 4)
    }

    if ($Model -notmatch '^\w{4,5}$') 
    {
        throw "Could not parse computer model number. This may not be a Lenovo computer, or an unsupported model."
    }
   
    Return $Model  
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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\WingetHPAC.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\WingetHPAC\PS_WingetHPAC.log"
$LogErr = "C:\Windows\Temp\Logs\WingetHPAC\PS_WingetHPAC.nok"
$LogDir = "C:\Windows\Temp\Logs\WingetHPAC"
$tempdirectory = "C:\Windows\Temp\WingetHPAC"

CreateDir $LogDir
CreateDir $DirAuto
CreateDir $tempdirectory

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

Write-Host "Begin"
Write-Host $scriptVersion

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now

$Manufacturer = Manufacturer

if ($Manufacturer -eq 'HP')
{

    try
    {
        # Copy the files
        write-host "Copy Files"
        Copy-Item ".\files\*" $tempdirectory -Force -Recurse  
   
        Set-Location $tempdirectory

        write-host "Install HP Accessory Center"
        # winget install "HP Accessory Center" --accept-source-agreements --accept-package-agreements --scope machine --source msstore
        Add-AppProvisionedPackage -Online -PackagePath Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64__8wekyb3d8bbwe.Appx -SkipLicense
        Add-AppProvisionedPackage -Online  -PackagePath AD2F1837.HPAccessoryCenter_2.16.3374.0_neutral_~_v10z8vjag6ke6.AppxBundle  -SkipLicense

        Add-AppPackage -Path Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64__8wekyb3d8bbwe.Appx
        Add-AppPackage -Path AD2F1837.HPAccessoryCenter_2.16.3374.0_neutral_~_v10z8vjag6ke6.AppxBundle
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr  
    }
}
Else
{
    write-host "Nothing to do not a HP Model"
}



write-host "Clean Up"
    
Set-Location c:\
	
if ((Test-Path -Path $TempDirectory))
{
    Remove-Item -Path $TempDirectory -Force -Recurse
}


$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript

# https://apps.microsoft.com/detail/9P87FCQVTC59?hl=en-us&gl=PT&ocid=pdpshare