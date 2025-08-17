$scriptVersion = "20250817"
$reboot = $false

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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\MsOffice.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\MsOffice\PS_MsOffice.log"
$LogErr = "C:\Windows\Temp\Logs\MsOffice\PS_MsOffice.nok"
$LogDir = "C:\Windows\Temp\Logs\MsOffice"
$tempDirectory = "C:\Windows\Temp\MsOffice"


$version = "18526"
$name = "SEMI-ANNUAL-ENTERPRISE-CHANNEL#VERSION"
$webversion = 0
$URI="https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date"

CreateDir $LogDir
CreateDir $DirAuto
CreateDir $tempDirectory

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now

#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

try
{

    $filessource = (get-Location).Path
    $filessource = Join-Path -Path $filessource -ChildPath "Files"
    if (-NOT(Test-Path -Path $filessource))
    {
        Write-host "Source files not Found"
        ForceErr
    }
    
    # Copy the Reg files
    write-host "Copy Files"
    Copy-Item ".\files\*" $tempDirectory -Force -Recurse  

    # Download Office
    Set-Location $tempDirectory

    $HTML = Invoke-WebRequest -Uri $URI
    $result = $HTML.Links

    foreach ($item in $result)
    {
    if ($item -like "*$version*")
    {
        if ($item.outerHTML.ToUpper() -like "*$name*")
        {
            $webversiontemp = ($item.outerText.Split(" ")[-1]).replace(")","")

            if ($webversion -lt $webversiontemp)
            {
                $webversion = $webversiontemp
            }    
        }

    }
}

    $readfile = (Get-Content -Path C:\Temp\O365\i64C2R_Template.xml) -replace "XXXXX.ZZZZZ", $webversion
    $newfile = Join-Path -Path $tempDirectory -ChildPath "i64C2RDownload.xml"
    Out-File -FilePath $newfile -InputObject $readfile

    # Build the path to the exe file
    $exePath = Join-Path -Path $tempDirectory -ChildPath "setup.exe"
    $downloadpath
    $configpath = Join-Path -Path $currentDirectory -ChildPath "i64C2R.xml"
    
    $argumentos = "/configure " + $configpath
    Write-Host "Command is $exePath"
    Write-Host "Arguments are $argumentos"
               
    $run = Start-Process -FilePath $exePath -ArgumentList $argumentos -Wait -NoNewWindow -PassThru
            
    if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010))
    {    
        Write-host "$Error[0]"
        ForceErr
    }   

    if (($run.ExitCode -eq 1641) -or ($run.ExitCode -eq 3010))
    {    
        $reboot = $true
    }


    if ($reboot -eq $true)
    {
        Write-host "Reboot needed"
    }
    else
    {
        Write-host "No Reboot needed"
    }

    $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
    AutoPilot "End  " $now
    $intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
    Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
    Stop-Transcript
}
catch 
{
    Write-host "$Error[0]"
    ForceErr
}

exit 0

if ($reboot -eq $true)
{
    exit 1641
}
else
{
    exit 0
}

