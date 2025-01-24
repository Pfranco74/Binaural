# HP Accessory Center Link
# https://apps.microsoft.com/detail/9P87FCQVTC59?hl=en-us&gl=PT&ocid=pdpshare
Remove-Variable * -ErrorAction SilentlyContinue

$scriptVersion = "20250123"

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

function GiveRights ($folder, $user)
{


    Write-Host "Set File Permission to $folder"
    $ACL = Get-ACL -Path $Folder
    
    $user = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList @([System.Security.Principal.WellKnownSidType]::AuthenticatedUserSid, $null)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'Read', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -Path $folder -AclObject $acl

}

function CheckPermission ($folder, $user)
{
    $getuser = 'NT AUTHORITY\' + $user

    $setpermission = $true

    $permission = (Get-Acl $Folder).Access | ?{$_.IdentityReference -match $User} | Select IdentityReference,FileSystemRights

    If ($permission)
    {
        foreach ($sec in $permission)
        {
            if ($sec.FileSystemRights -notlike "-*")
            {
                [string]$VerifyPermission = $sec.FileSystemRights
                if (($VerifyPermission.ToUpper()).contains("MODIFY") -or ($VerifyPermission.ToUpper()).contains("FULLCONTROL"))
                {
                    $setpermission = $false              
                }
            }      
        }
    }

    Return $setpermission
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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\HPAC.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\HPAC\PS_HPAC.log"
$LogErr = "C:\Windows\Temp\Logs\HPAC\PS_HPAC.nok"
$LogDir = "C:\Windows\Temp\Logs\HPAC"
$tempdirectory = "C:\Windows\Temp\HPAC"
$folder = "C:\Program Files\WindowsApps\AD2F1837.HPAccessoryCenter_2.16.3374.0_x64__v10z8vjag6ke6"


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
   
        $vclibs = Join-Path $tempdirectory -ChildPath "Microsoft.VCLibs.140.00.UWPDesktop_14.0.33728.0_x64__8wekyb3d8bbwe.Appx"
        $hpac = Join-Path $tempdirectory -ChildPath "AD2F1837.HPAccessoryCenter_2.16.3374.0_neutral_~_v10z8vjag6ke6.AppxBundle"
        write-host "Install HP Accessory Center"
        # winget install "HP Accessory Center" --accept-source-agreements --accept-package-agreements --scope machine --source msstore
        
        Add-AppProvisionedPackage -Online -PackagePath $vclibs -SkipLicense
        Add-AppProvisionedPackage -Online -PackagePath $hpac -SkipLicense

        Add-AppPackage -Path $vclibs
        Add-AppPackage -Path $hpac

        # Load Default User Profile to registry

        reg.exe load HKLM\TempUser "C:\Users\Default\NTUSER.DAT" | Out-Host

        # Get Reg Files
        $List = Get-ChildItem -Path $TempDirectory -filter "*.reg"

        # Process List of Reg Files
        foreach ($item in $list)
        {
            try
            {
                $Name = ($item.Name).Split(".")[0]
                $Command = "c:\windows\regedit.exe"
                $parm = "/S " + $item.FullName
                $run = (Start-Process $Command -ArgumentList $parm -Wait -PassThru)
            }
            catch
            {
                Write-host "$Error[0]"
                ForceErr
            }
        }

        # Unload Default User Profile from registry
        reg.exe unload HKLM\TempUser | Out-Host
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

