$scriptVersion = "20241109"

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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\UpdateOS.log"
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
Write-Host $scriptVersion

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
    Reset-WUComponents
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
                    Install-WindowsUpdate -WindowsUpdate -AcceptAll -IgnoreReboot -Verbose -UpdateID ($item.Identity).UpdateID -ErrorAction SilentlyContinue | Select Title, KB, Result | Format-Table
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
            Install-WindowsUpdate -WindowsUpdate -AcceptAll -IgnoreReboot -Verbose -UpdateID ($item.Identity).UpdateID -ErrorAction SilentlyContinue  | Select Title, KB, Result | Format-Table
            Start-Sleep -Seconds 7
        }
    }
}
catch
{
    Write-Output "error install update $updateid"
    #ForceErr
}

#Check Install Update
try
{
    $modelExecption = $false
    $Manufacturer = Manufacturer

    if ($Manufacturer -eq 'LENOVO')
    {
        #Get Computer Model
        $model = ComputerModel
        Write-Host "Lenovo Model is: $Model" 
    }

    if ($model -eq '20WL')
    {
        $modelExecption = $True        
    }
}
catch
{
    Write-host "$Error[0]"
    ForceErr  
}

if (Test-Path -Path "C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS.log")
{
    $readfile = get-content -Path C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS.log
    $founderror = $null    
}
else
{
    write-host "File not found C:\Windows\Temp\Logs\UpdateOS\PS_UpdateOS.log"
    ForceErr
}

if ($modelExecption -eq $false)
{
    foreach ($item in $readfile)
    {
        if (($item.ToUpper()).contains("FAILED"))
        {        
            $foundfailed = $item     
            $founderror = $founderror + @($foundfailed)  
        }
    }

    if ($founderror.Count -ne 0)
    {
        write-host "Found error"
        Write-Output $founderror
        ForceErr
    }
    else
    {
     Write-Host "No errors detect"
    }    
}
else
{
    Write-Host "Skip Check Model Execption" 
}

# Specify return code
$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"

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
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript

Exit 1641
