
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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\Acrobat.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\Acrobat\PS_Acrobat.log"
$LogErr = "C:\Windows\Temp\Logs\Acrobat\PS_Acrobat.nok"
$LogDir = "C:\Windows\Temp\Logs\Acrobat"
$tempDirectory = "C:\Windows\Temp\Acrobat"


CreateDir $LogDir
CreateDir $DirAuto
CreateDir $tempDirectory

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now

#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

try
{

    # Copy the Reg files
    Copy-Item ".\files\*" $tempDirectory -Force -Recurse  

    $files = Get-ChildItem -Path $tempDirectory

    foreach ($item in $files)
    {
        if (($item.FullName.ToUpper()).contains(".EXE") -eq $true)
        {
            $arg = "/sAll /rs"
            
            $run = Start-Process -FilePath $item.FullName -ArgumentList $arg -Wait
            
            if (($run.ExitCode -ne 0) -or ($run.ExitCode -ne 3010))
            {    
                Write-host "$Error[0]"
                ForceErr
            }   
        }
        
        if ((($item.FullName.ToUpper()).contains(".MSP") -eq $true) -or (($item.FullName.ToUpper()).contains(".MSI") -eq $true))
        {
            $arg = "/quiet /norestart /l*v " + $LogDir + "\" + $item.Name + ".log"
            
            $run = Start-Process -FilePath $item.FullName -ArgumentList $arg -Wait   

            if (($run.ExitCode -ne 0) -or ($run.ExitCode -ne 3010))
            {    
                Write-host "$Error[0]"
                ForceErr
            }   

        }
        
    }

    if ((Test-Path "c:\users\public\desktop\Acrobat Reader DC.lnk"))
    {
        Remove-Item -Path "c:\users\public\desktop\Acrobat Reader DC.lnk" -Force
    }

    
    if ((Test-Path -Path $TempDirectory))
    {
        Remove-Item -Path $TempDirectory -Force -Recurse
    }

    $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
    AutoPilot "End  " $now
    Stop-Transcript
}
catch 
{
    Write-host "$Error[0]"
    ForceErr
}