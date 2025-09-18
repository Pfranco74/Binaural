$scriptVersion = "20250918"

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

    if ($Manufacturer -eq 'LENOVO')
    {

        if ($Model.Length -gt 5) 
        {
            $Model = $Model.Substring(0, 4)
        }

        if ($Model -notmatch '^\w{4,5}$') 
        {
            throw "Could not parse computer model number. This may not be a Lenovo computer, or an unsupported model."
        }        
    }

    if ($Manufacturer -eq 'HP')
    {
        $model = $Model.replace(" ","")
    }


    Return $Model  
}

function SendMsg
{
    install-module RunAsUser
    $sb =
    {
        Add-Type -AssemblyName PresentationCore,PresentationFramework
        $msgbody = "Erro na configuração do adaptador da CASH, regularize a configuração instalando o MM Prolific Config através do Portal da Empresa"
        $msgimage = "Hand"
        [System.Windows.MessageBox]::Show($msgbody,'Mensagem','Ok','Error')
    }
    Invoke-AsCurrentUser -ScriptBlock $sb
}

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITECTURE" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\MBCPTools.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\MBCPTools\PS_MBCPTools.log"
$LogErr = "C:\Windows\Temp\Logs\MBCPTools\PS_MBCPTools.nok"
$LogDir = "C:\Windows\Temp\Logs\MBCPTools"
$EutilsDir = 'C:\Program Files\Eutils'
$ModelCerti = @("11DG","11U6","20L6","20N2","20N3","20SY","20T3","20WL","21AJ","21BQ","21EY","21HE","21LX","21MM","30C8","HPElitex36083013inchG112-in-1NotebookPC","HPEliteBook8FlipG1i13inchNotebookAIPC","HPEliteBook83013inchG11NotebookPC","HPProMini400G9DesktopPC","HPProt550ThinClient","Latitude 7320 Detachable","Surface Pro 8")
$install = $false



CreateDir $LogDir
CreateDir $DirAuto


DelFile $LogFile
DelFile $LogErr

# Start logging
Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion  

# Set time zone
Set-TimeZone -id 'GMT Standard Time'

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now

#Get Computer Model
$Manufacturer = Manufacturer
$model = ComputerModel
Write-Host "This is a $Manufacturer model $model" 

foreach ($item in $ModelCerti)
{
    if ($item.toupper() -eq $model.ToUpper())
    {
        Write-host "This model $model is certified"
        $install = $true
    }
}

if ($install -ne 'True')
{
    Write-host "This model $model is not certified"
    $argsmsg = "console /time:259200 ""This model $model is not certified"""
    Start-Process -FilePath 'MSG' -ArgumentList $argsmsg -WindowStyle Maximized
    ForceErr
}

try
{
    $oem = Get-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'

    if ((([string]::IsNullOrWhitespace($OEM.Logo)) -ne $true))
    {
        Write-Host "Detect OEM image reference"
        $argsmsg = "console /time:259200 ""Detect OEM image reference"""
        Start-Process -FilePath 'MSG' -ArgumentList $argsmsg -WindowStyle Maximized
        ForceErr
    }
}
catch 
{
    Write-host "$Error[0]"
    ForceErr
}



try
{
    CreateDir $EutilsDir
    # Copy the Reg files
    Copy-Item ".\files\*" $EutilsDir -Force
}
catch 
{
    Write-host "$Error[0]"
    ForceErr
}

try
{
    # Definir o tamanho m ximo do arquivo de log em bytes (10MB)
    $maxLogSizeInBytes = 10485760
 
    # Definir o n mero m ximo de arquivos de log a serem mantidos
    $maxLogFiles = 3
 
    # Verificar se a chave de registro de log existe e cri -la se n o existir
    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging")) 
    {
        $null = New-Item -Path "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging"
    }
 
    # Definir os valores do registro para as configura  es de log
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging" -Name "LogMaxSize" -Value $maxLogSizeInBytes
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging" -Name "LogMaxHistory" -Value $maxLogFiles
 
    # Reiniciar o servi o Intune Management Extension para aplicar as mudan as
    Restart-Service -Name "IntuneManagementExtension"
}
catch
{
    Write-host "$Error[0]"
    ForceErr
}

#Config Powershell Policy
Write-Host "Config Powershell Policy"    
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue -Verbose

    
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

    Set-ItemProperty -Path $VersionLocation -Name "MBCPTools" -Value $version
}
catch
{
    Write-host "$Error[0]"
    ForceErr
}

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript


