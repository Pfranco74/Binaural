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
    
    # Copy files
    write-host "Copy Files"
    Copy-Item ".\files\*" $tempDirectory -Force -Recurse  

    # Create XML
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

    # Download Files
    $exePath = Join-Path -Path $tempDirectory -ChildPath "setup.exe"
    $downloadpath = Join-Path -Path $tempDirectory -ChildPath "i64C2RDownload.xml"
    
    $argumentos1 = "/download " + $downloadpath
    Write-Host "Command is $exePath"
    Write-Host "Arguments are $argumentos1"
               
    $run = Start-Process -FilePath $exePath -ArgumentList $argumentos1 -Wait -NoNewWindow -PassThru
            
    if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010))
    {    
        Write-host "$Error[0]"
        ForceErr
    }   
    
    # Install MSOffice
    $argumentos2 = "/configure " + $configpath
    Write-Host "Command is $exePath"
    Write-Host "Arguments are $argumentos2"
               
    $run = Start-Process -FilePath $exePath -ArgumentList $argumentos2 -Wait -NoNewWindow -PassThru
            
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

    #cleanup
    Write-Host "CleanUp Files"
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

