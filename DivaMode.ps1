$scriptVersion = "20250131"

function ForceErr
{
    Stop-Transcript
    Rename-Item -Path $LogFile -NewName $LogErr -Force
    
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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\PKG.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\PKG\PS_PKG.log"
$LogErr = "C:\Windows\Temp\Logs\PKG\PS_PKG.nok"
$LogDir = "C:\Windows\Temp\Logs\PKG"

CreateDir $LogDir

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion


$Manufacturer = Manufacturer

if ($Manufacturer -eq 'HP')
{
    Write-Output "HP Model"
    Write-Output "Mark to skip Lenovo Packages"
    New-Item -Path C:\Windows\Temp\Logs\20T3 -Name PS_20T3.log -Force
    New-Item -Path C:\Windows\Temp\Logs\20WL -Name PS_20WL.log -Force
    New-Item -Path C:\Windows\Temp\Logs\21BQ -Name PS_21BQ.log -Force
    New-Item -Path C:\Windows\Temp\Logs\21EY -Name PS_21EY.log -Force    
    New-Item -Path C:\Windows\Temp\Logs\Bios -Name PS_Lenovo_Bios_Update.log -Force
    New-Item -Path C:\Windows\Temp\Logs\Bios -Name PS_Lenovo_Bios_Config.log -Force
}

if ($Manufacturer -eq 'LENOVO')
{
    $model = ComputerModel
    Write-Host "This is a $Manufacturer model $model" 

    if ($model -eq '20T3')
    {
        New-Item -Path C:\Windows\Temp\Logs\20T3 -Name PS_20WL.log -Force
        New-Item -Path C:\Windows\Temp\Logs\20WL -Name PS_21BQ.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21BQ -Name PS_21EY.log -Force
    }

    if ($model -eq '20WL')
    {
        New-Item -Path C:\Windows\Temp\Logs\20T3 -Name PS_20T3.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21BQ -Name PS_21BQ.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21EY -Name PS_21EY.log -Force        
    }

    if ($model -eq '21BQ')
    {
        New-Item -Path C:\Windows\Temp\Logs\20T3 -Name PS_20T3.log -Force
        New-Item -Path C:\Windows\Temp\Logs\20WL -Name PS_20WL.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21EY -Name PS_21EY.log -Force        
    }

    if ($model -eq '21EY')
    {
        New-Item -Path C:\Windows\Temp\Logs\20T3 -Name PS_20T3.log -Force
        New-Item -Path C:\Windows\Temp\Logs\20WL -Name PS_20WL.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21BQ -Name PS_21BQ.log -Force
    }

    if (($model -ne '20T3') -and ($model -ne '20WL') -and ($model -ne '21BQ') -and ($model -ne '21EY'))
    {
        New-Item -Path C:\Windows\Temp\Logs\20T3 -Name PS_20T3.log -Force
        New-Item -Path C:\Windows\Temp\Logs\20WL -Name PS_20WL.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21BQ -Name PS_21BQ.log -Force
        New-Item -Path C:\Windows\Temp\Logs\21EY -Name PS_21EY.log -Force 
    }

    New-Item -Path C:\Windows\Temp\Logs\HPCMSL -Name PS_HPCMSL.log -Force
    New-Item -Path C:\Windows\Temp\Logs\Bios -Name PS_HP_Bios_Update.log -Force
    New-Item -Path C:\Windows\Temp\Logs\Bios -Name PS_HP_Bios_Config.log -Force
    New-Item -Path C:\Windows\Temp\Logs\Monitor -Name PS_HP_MonitorE24m.log -Force
}

Stop-Transcript

