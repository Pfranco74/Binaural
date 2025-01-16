$scriptVersion = "20250110"
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

function UnistMsi ($id,$appname)
{
    
            $command = "c:\Windows\System32\msiexec.exe"

            $argumentos = "/x" + $id + " /quiet /norestart /l*v " + $LogDir + "\" + $appname + ".log"
            
            $run = Start-Process -FilePath $command -ArgumentList $argumentos -Wait -PassThru

            write-host $run.ExitCode

            if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010) -and ($run.ExitCode -ne 1605))
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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\20WL.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\20WL\PS_20WL.log"
$LogErr = "C:\Windows\Temp\Logs\20WL\PS_20WL.nok"
$LogDir = "C:\Windows\Temp\Logs\20WL"
$tempDirectory = "C:\Windows\Temp\20WL"
$tempDrv = "C:\Temp\Drv"


CreateDir $LogDir
CreateDir $DirAuto
CreateDir $tempDirectory
CreateDir $tempDrv

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


$Manufacturer = Manufacturer
$model = ComputerModel
Write-Host "This is a $Manufacturer model $model" 
    

if ($model -ne '20WL')
{
    Write-Output "Skip Update not 20WL Lenovo Model"
    $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
    AutoPilot "End  " $now
    $intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
    Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
    Stop-Transcript
    exit 0
}


try
{
    # Copy the files
    write-host "Copy Files"
    Copy-Item ".\files\*" $tempDrv -Force -Recurse  

    $files = Get-ChildItem -Path $tempDrv
    $argumentos = "-s -o"	
    $command = $tempDrv + "\Video\Installer.exe"
        
    if (Test-Path -Path $command)
    {
        Set-Location $tempDrv\video
	    Write-Host "Install Video Driver"
        $run = Start-Process -FilePath $command -ArgumentList $argumentos -Wait -PassThru
            
        if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010) -and ($run.ExitCode -ne 14))
        {    
            Write-host "$Error[0]"
            ForceErr
        }

    }
    else
    {
        Write-host "File not found $command"
        ForceErr
    }
}
catch
{
    Write-host "$Error[0]"
    ForceErr  
}

 Import-Module PSWindowsUpdate

 # Install all available updates
 $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
 Write-Output "$ts Installing updates."
 try
{
    #Reset-WUComponents
    $GETUPDATES = Get-WindowsUpdate -AcceptAll -WindowsUpdate -UpdateType Driver -IgnoreReboot
    $CheckNumberUpdates = $GETUPDATES.Count
    $UpdatetobeInstall = $GETUPDATES | select Title
    Write-Output "Detect $CheckNumberUpdates Updates"
    Write-Output $UpdatetobeInstall
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
    }
    Else
    {
        write-host "No updates available"
        ForceErr
    }
}
catch
{
    Write-Output "error install update $updateid"
    #ForceErr
}


write-host "Clean Up"
    
Set-Location c:\
	
if ((Test-Path -Path $TempDirectory))
{
    Remove-Item -Path $TempDirectory -Force -Recurse
}

if ((Test-Path -Path $TempDrv))
{
    Remove-Item -Path $TempDrv -Force -Recurse
}


if (Test-Path -Path "C:\Windows\Temp\Logs\20WL\PS_20WL.log")
{
    $readfile = get-content -Path "C:\Windows\Temp\Logs\20WL\PS_20WL.log"
    $founderror = $null    
}
else
{
    write-host "File not found C:\Windows\Temp\Logs\20WL\PS_20WL.log"
    ForceErr
}

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

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript

exit 1641
