$scriptVersion = "20240913"

# Log Function
function Write-Log($string)
{
    $dateTimeNow = Get-Date -Format "dd.MM.yyyy - HH:mm:ss"
    $outStr = "" + $dateTimeNow +" "+$string
    Write-Output $outStr     
}

function GetLanguagePack ($lang)
{
    $lang = $lang.toupper()
    $LanguagePackInstall = $False
    $GetInstallPackaged = Get-WindowsPackage -Online
    foreach ($item in ($GetInstallPackaged).packagename)
    {
        $item = $item.ToUpper()
        $langlike =  "*" + $lang + "*"       
        if ($item -like $langlike)
        {     
            if ($item.ToUpper() -like '*MICROSOFT-WINDOWS-CLIENT-LANGUAGEPACK-PACKAGE*')
            {
                if ((Get-WindowsPackage -Online -PackageName $item).packagestate -eq 'Installed')
                {
                    $LanguagePackInstall = $True
                }              
            }   
        }
    }
    Return $LanguagePackInstall
}

function GetLanguagePackApp ($lang, $app)
{
    $LanguagePackAppInstall = $False
    $lang = $lang.toupper()
    $app = $app.toupper()
    $app = ($app.Split("-"))[2]
    $applike = "*" + $app + "*"

    $GetInstallPackaged = Get-WindowsPackage -Online
    foreach ($item in ($GetInstallPackaged).packagename)
    {
        $item = $item.ToUpper()       
        if ($item -like $applike)
        {
            if ((Get-WindowsPackage -Online -PackageName $item).packagestate -eq 'Installed')
            {                
                $LanguagePackAppInstall = $True
            }              
        }
    }
    Return $LanguagePackAppInstall
}

function GetLIP ($lang, $app)
{
    $LanguageLIPInstall = $False
    $lang = $lang.toupper()
    $lip = $app.toupper()
    $lip = ($lip.Split("."))[1]
    $liplike = "*" + $lip + "*"

    $GetInstallPackaged = Get-AppxProvisionedPackage -online

    foreach ($item in ($GetInstallPackaged).displayname)
    {
        $item = $item.ToUpper()       
        if ($item -like $liplike)
        {
            $LanguageLIPInstall = $True
        }
    }
    Return $LanguageLIPInstall
}

function GetFeatures ($app)
{
    $LanguageFeaturesInstall = $False
    $Features = $app.toupper()
    $Features = ($Features.Split("."))[0]
    $Featureslike = "*" + $Features + "*"
  
    $GetInstallPackaged = Get-WindowsPackage -Online
    foreach ($item in ($GetInstallPackaged).packagename)
    {
        $item = $item.ToUpper()
        if ($item -like $Featureslike)
        {
            $LanguageFeaturesInstall = $True
        }
    }
    Return $LanguageFeaturesInstall
}

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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\LP.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\LP\PS_LP.log"
$LogErr = "C:\Windows\Temp\Logs\LP\PS_LP.nok"
$LogDir = "C:\Windows\Temp\Logs\LP"
$TempDirectory = "C:\Windows\Temp\LP"


CreateDir $LogDir
CreateDir $DirAuto
CreateDir $TempDirectory

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now



Write-Log "------------ Start Script  ------------"
Write-Log ""
Write-Log ""
Write-Log "---------------------------------------"
Write-Log "Operating System version"
Write-Log "---------------------------------------"
 


# Check Operating System version
$Operver = ([System.Environment]::OSVersion.Version).build
Write-Log "Operating System Verion $Operver"
$OperLang = ((Get-WinUserLanguageList)[0].autonym)
Write-Log "Operating System Language $OperLang"

# Set time zone
Set-TimeZone -id 'GMT Standard Time'
Write-Log "Get-Time Zone"
Write-log  (Get-TimeZone).id

# Windows 10 Block
if (([string]$Operver).substring(0,2) -eq '19')
{
    if ($OperLang.Split(" ")[0] -eq 'English')
    {
        write-log "Process Windows 10 English Version"
        $VerLang = 'pt-pt'
        try
        {
            # Copy Files
            write-log "Copy Files"
            Copy-Item ".\WinX\LanguagePack\*" $TempDirectory -Recurse -Force

            # Install language Pack
            write-log "Check Language Pack"
            $LpPackInstall = GetLanguagePack $VerLang
            if ($LpPackInstall -eq $False)
            {
                write-log "Install Language Pack"
                $LpPack = Get-ChildItem -Path $TempDirectory\cab\$VerLang\ -file
                foreach ($item in $LpPack)
                {                    
                    $LPpackagename = $TempDirectory + "\cab\$VerLang\" + $item.name
                    Write-Log "Install Language Pack $LPpackagename"
                    Add-WindowsPackage -Online -PackagePath $LPpackagename -NoRestart    
                }                
            }
           
            # Install APP language Pack
            write-log "Check APP Language Pack"
            $AppPack = Get-ChildItem -Path $TempDirectory\App\$VerLang\ -File
            foreach ($item in $APPPack)
            {
                $AppLpinstall = GetLanguagePackApp $verlang $item.name
                if ($AppLpinstall -eq $False)
                {                    
                    $APPpackagename = $TempDirectory + "\App\$VerLang\" + $item.name
                    write-log "Install APP Language Pack $APPpackagename"
                    Add-WindowsPackage -Online -PackagePath $APPpackagename -NoRestart                        
                }
            }

            # Check Language Interface PAck
            write-log "Check Language Interface Pack"        
            $appxbundle = Get-ChildItem -Path $TempDirectory\LIP\ -Recurse -Filter *.appx -ErrorAction Stop
            foreach ($item in $appxbundle)
            {
                $LipInstall = GetLIP $VerLang $Item.Name
                if ($LipInstall -eq $False)
                {
                    write-log "InstallLanguage Interface pack $item.FullName"
                    Add-AppxProvisionedPackage -Online -PackagePath $item.FullName -SkipLicense                                  
                }
            }
    
            # Install language Features
            write-log "Check Language Feature Pack"
            $FeaPack = Get-ChildItem -Path $TempDirectory\FEA\ -Filter *.cab -Recurse
            foreach ($item in $FeaPack)
            {
                $featureInstall = GetFeatures $item.Name
                if ($featureInstall -eq $false)
                {                    
                    $Feapackagename = $item.FullName
                    write-log "Install Language Feature Pack $Feapackagename"
                    Add-WindowsPackage -Online -PackagePath $Feapackagename -NoRestart
                }
            }
            #Force PT Settings
            write-log "Force Portuguese Settings"
            $XMLfile = Get-ChildItem -Path $TempDirectory\PT\ -Filter pt-PT.xml -ErrorAction Stop
            $XML = $TempDirectory + "\pt\" + $XMLfile
            & $env:SystemRoot\system32\control.exe "intl.cpl,,/f:`"$XML`""
            start-sleep -seconds 2
            Set-WinUserLanguageList pt-PT –Force

    }
        catch
        {
            write-log "Unknown Execption"
            Write-host "$Error[0]"
            ForceErr
        }
    }

    if ($OperLang.Split(" ")[0] -eq 'Português')
    {
        write-log "Process Windows 10 Português Version"
        $VerLang = 'en-us'
        try
        {
            # Copy Files
            write-log "Copy Files"
            Copy-Item ".\WinX\LanguagePack\*" $TempDirectory -Recurse -Force

            # Install language Pack
            write-log "Check Language Pack"
            $LpPackInstall = GetLanguagePack $VerLang
            if ($LpPackInstall -eq $False)
            {                
                $LpPack = Get-ChildItem -Path $TempDirectory\cab\$VerLang\ -file
                foreach ($item in $LpPack)
                {
                    $LPpackagename = $TempDirectory + "\cab\$VerLang\" + $item.name
                    write-log "Install Language Pack $LPpackagename"
                    Add-WindowsPackage -Online -PackagePath $LPpackagename -NoRestart    
                }                
            }
           
            # Install APP language Pack
            write-log "Check APP Language Pack"
            $AppPack = Get-ChildItem -Path $TempDirectory\App\$VerLang\ -File
            foreach ($item in $APPPack)
            {
                $AppLpinstall = GetLanguagePackApp $verlang $item.name
                if ($AppLpinstall -eq $False)
                {
                    $APPpackagename = $TempDirectory + "\App\$VerLang\" + $item.name
                    write-log "Install APP Language Pack $APPpackagename"
                    Add-WindowsPackage -Online -PackagePath $APPpackagename -NoRestart                        
                }
            }

            # Check Language Interface PAck
            write-log "Check Language Interface Pack"        
            $appxbundle = Get-ChildItem -Path $TempDirectory\LIP\ -Recurse -Filter *.appx -ErrorAction Stop
            foreach ($item in $appxbundle)
            {
                $LipInstall = GetLIP $VerLang $Item.Name
                if ($LipInstall -eq $False)
                {
                    write-log "InstallLanguage Interface pack $item.Fullname"
                    Add-AppxProvisionedPackage -Online -PackagePath $item.FullName -SkipLicense                                  
                }
            }
    
            # Install language Features
            write-log "Check Language Feature Pack"
            $FeaPack = Get-ChildItem -Path $TempDirectory\FEA\ -Filter *.cab -Recurse
            foreach ($item in $FeaPack)
            {
                $featureInstall = GetFeatures $item.Name
                if ($featureInstall -eq $false)
                {
                    $Feapackagename = $item.FullName
                    write-log "Install Language Feature Pack $Feapackagename"
                    Add-WindowsPackage -Online -PackagePath $Feapackagename -NoRestart
                }
            }

            #Force PT Settings
            write-log "Force Portuguese Settings"
            $XMLfile = Get-ChildItem -Path $TempDirectory\PT\ -Filter pt-PT.xml -ErrorAction Stop
            $XML = $TempDirectory + "\pt\" + $XMLfile
            & $env:SystemRoot\system32\control.exe "intl.cpl,,/f:`"$XML`""
            start-sleep -seconds 2
            Set-WinUserLanguageList pt-PT –Force

    }
        catch
        {
            write-log "Unknown Execption"
            Write-host "$Error[0]"
            ForceErr
        }
    }

}

# Windows 11 Block
if (([string]$Operver).substring(0,2) -eq '22')
{
    if ($OperLang.Split(" ")[0] -eq 'English')
    {
        $VerLang = 'pt-pt'
        write-log "Process Windows 11 English Version"
        try
        {
            # Copy Files
            write-log "Copy Files"
            Copy-Item ".\WinXI\LanguagePack\*" $TempDirectory -Recurse -Force

            # Install language Pack
            
            $LpPack = Get-ChildItem -Path $TempDirectory\cab\$VerLang\ -file
            foreach ($item in $LpPack)
            {
                $LPpackagename = $TempDirectory + "\cab\$VerLang\" + $item.name
                write-log "Install Language Pack $LPpackagename"
                Add-WindowsPackage -Online -PackagePath $LPpackagename -NoRestart    
            }
           
            # Install APP language Pack
            $AppPack = Get-ChildItem -Path $TempDirectory\App\$VerLang\ -File
            foreach ($item in $APPPack)
            {
                $APPpackagename = $TempDirectory + "\App\$VerLang\" + $item.name
                write-log "Install APP Language Pack $APPpackagename"
                Add-WindowsPackage -Online -PackagePath $APPpackagename -NoRestart                        
            }

            # Check Language Interface PAck     
            $appxbundle = Get-ChildItem -Path $TempDirectory\LIP\ -Recurse -Filter *.appx -ErrorAction Stop
            foreach ($item in $appxbundle)
            {
                write-log "InstallLanguage Interface pack $item.fullname"
                Add-AppxProvisionedPackage -Online -PackagePath $item.FullName -SkipLicense                                  
            }
    
            # Install language Features
            $FeaPack = Get-ChildItem -Path $TempDirectory\FEA\ -Filter *.cab -Recurse
            foreach ($item in $FeaPack)
            {
                $featureInstall = GetFeatures $item.Name
                if ($featureInstall -eq $false)
                {                    
                    $Feapackagename = $item.FullName
                    write-log "Install Language Feature Pack $Feapackagename"
                    Add-WindowsPackage -Online -PackagePath $Feapackagename -NoRestart
                }
            }

            #Force PT Settings
            write-log "Force Portuguese Settings"
            $XMLfile = Get-ChildItem -Path $TempDirectory\PT\ -Filter pt-PT.xml -ErrorAction Stop
            $XML = $TempDirectory + "\pt\" + $XMLfile
            & $env:SystemRoot\system32\control.exe "intl.cpl,,/f:`"$XML`""
            start-sleep -seconds 2
            Set-WinUserLanguageList pt-PT –Force

    }
        catch
        {
            write-log "Unknown Execption"
            Write-host "$Error[0]"
            ForceErr
        }
    }

    if ($OperLang.Split(" ")[0] -eq 'Português')
    {
        $VerLang = 'en-us'
        write-log "Process Windows 11 Portuguese Version"
        try
        {
            # Copy Files
            write-log "Copy Files"
            Copy-Item ".\WinXI\LanguagePack\*" $TempDirectory -Recurse -Force

            # Install language Pack
            $LpPack = Get-ChildItem -Path $TempDirectory\cab\$VerLang\ -file
            foreach ($item in $LpPack)
            {
                $LPpackagename = $TempDirectory + "\cab\$VerLang\" + $item.name
                write-log "Install Language Pack $LPpackagename"
                Add-WindowsPackage -Online -PackagePath $LPpackagename -NoRestart   
            }                
           
            # Install APP language Pack
            write-log "Check APP Language Pack"
            $AppPack = Get-ChildItem -Path $TempDirectory\App\$VerLang\ -File
            foreach ($item in $APPPack)
            {
                $APPpackagename = $TempDirectory + "\App\$VerLang\" + $item.name
                write-log "Install APP Language Pack $APPpackagename"
                Add-WindowsPackage -Online -PackagePath $APPpackagename -NoRestart
            }

            # Check Language Interface PAck
            write-log "Check Language Interface Pack"        
            $appxbundle = Get-ChildItem -Path $TempDirectory\LIP\ -Recurse -Filter *.appx -ErrorAction Stop
            foreach ($item in $appxbundle)
            {
                write-log "InstallLanguage Interface pack $item.fullname"
                Add-AppxProvisionedPackage -Online -PackagePath $item.FullName -SkipLicense                                  
            }

    
            # Install language Features
            write-log "Check Language Feature Pack"
            $FeaPack = Get-ChildItem -Path $TempDirectory\FEA\ -Filter *.cab -Recurse
            foreach ($item in $FeaPack)
            {
                $featureInstall = GetFeatures $item.Name
                if ($featureInstall -eq $false)
                {
                    $Feapackagename = $item.FullName
                    write-log "Install Language Feature Pack $Feapackagename"
                    Add-WindowsPackage -Online -PackagePath $Feapackagename -NoRestart
                }
            }

            #Force PT Settings
            write-log "Force Portuguese Settings"
            $XMLfile = Get-ChildItem -Path $TempDirectory\PT\ -Filter pt-PT.xml -ErrorAction Stop
            $XML = $TempDirectory + "\pt\" + $XMLfile
            & $env:SystemRoot\system32\control.exe "intl.cpl,,/f:`"$XML`""
            start-sleep -seconds 2
            Set-WinUserLanguageList pt-PT –Force

    }
        catch
        {
            write-log "Unknown Execption"
            Write-host "$Error[0]"
            ForceErr
        }
    }

    if (($OperLang.Split(" ")[0] -ne 'Português') -and ($OperLang.Split(" ")[0] -ne 'English'))
    {
        write-log "Wrong Base Language"
        Write-host "$Error[0]"
        ForceErr
    }

    if ((([string]$Operver).substring(0,2) -eq '22') -and (([string]$Operver).substring(0,2) -eq '10'))

    {
        write-log "Wrong Base Language"
        Write-host "$Error[0]"
        ForceErr
    }

}

if ((Test-Path -Path $TempDirectory))
{
   # Remove-Item -Path $TempDirectory -Force -Recurse
}

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

Set-ItemProperty -Path $VersionLocation -Name "Branding" -Value $version 


Write-Log ""
Write-Log "------------- End Script  -------------"
$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
Stop-Transcript


# SIG # Begin signature block
# MIIfQgYJKoZIhvcNAQcCoIIfMzCCHy8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPEjIr5kg+DYoAQs3RQegZrhu
# isugghmAMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
# AQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz
# 7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS
# 5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7
# bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfI
# SKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jH
# trHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14
# Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2
# h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt
# 6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPR
# iQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ER
# ElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4K
# Jpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAd
# BgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAC
# hjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRV
# HSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyh
# hyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO
# 0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo
# 8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++h
# UD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5x
# aiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGczCCBVug
# AwIBAgITIAADx1drX2DfBPsXiQABAAPHVzANBgkqhkiG9w0BAQsFADBQMRMwEQYK
# CZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPyLGQBGRYHYmNwY29ycDEgMB4GA1UE
# AxMXQkNQIEdyb3VwIElzc3VpbmcgQ0EgMDEwHhcNMjQwODEyMTQwNDQxWhcNMjYw
# ODEyMTQwNDQxWjBUMQswCQYDVQQGEwJQVDEPMA0GA1UEBxMGTGlzYm9hMRcwFQYD
# VQQKEw5NaWxsZW5uaXVtIEJDUDEbMBkGA1UEAwwSRW5kcG9pbnRTV19TaWduaW5n
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvFn4YZnZALAerpNoEJY/
# kcS0Uk7C2wDEGtZ0WEsvAgIAdCmhNbKecRs163yuHqPbE1CZZLc8YusxZ136nP3P
# CyEhy3qTKLSSPzYuMXqBKUt5wZsiIjZLqmVVRD+nBG5j8uRyqYUq9rn8/k6AVk1A
# 3SDl+9Z0TnKZpgeCBZ9kCEr6mQHcZgdRakzU1Lwzw7QC8V01E7+qpHVqDr11AyWz
# COwZfh67eTF6nwivECiePCjw5pZAFJFe550Lf+CPzjSnI2SfBG78c8mxwiFP2EMN
# 8SysyoyY+6z5+UrvKYgjdQlWvFHYcJJvoiN6nCTmX2JaDXZyZrqoG885TgsUyUCt
# cQIDAQABo4IDQDCCAzwwPQYJKwYBBAGCNxUHBDAwLgYmKwYBBAGCNxUIg63yDoKd
# unaRhSOF47xxhuXJE4FBhsOHZILXmBACAWQCAQ4wEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwCwYDVR0PBAQDAgeAME0GA1UdIARGMEQwQgYKKwYBBAGBgiQBAzA0MDIGCCsG
# AQUFBwIBFiZodHRwOi8vcGtpLmJjcC5wdC9kb2MvR3J1cG9CQ1BDUDAyLnBkZjAb
# BgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQbKmGj3+JhrNYx
# 7EldJelbU63MDzAfBgNVHSMEGDAWgBQJ3og3Fr8xWygusRL3v/SLEMMFcjCCARUG
# A1UdHwSCAQwwggEIMIIBBKCCAQCggf2GLWh0dHA6Ly9wa2kuYmNwLnB0L2NybC9C
# Q1BHcm91cElzc3VpbmdDQTAxLmNybIaBy2xkYXA6Ly8vQ049QkNQJTIwR3JvdXAl
# MjBJc3N1aW5nJTIwQ0ElMjAwMSxDTj1TRVRQU0ZJS0lDMDEsQ049Q0RQLENOPVB1
# YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRp
# b24sREM9YmNwY29ycCxEQz1uZXQ/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9i
# YXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50MIIBEgYIKwYBBQUH
# AQEEggEEMIIBADA9BggrBgEFBQcwAoYxaHR0cDovL3BraS5iY3AucHQvY2VydC9C
# Q1BHcm91cElzc3VpbmdDQTAxKDEpLmNydDCBvgYIKwYBBQUHMAKGgbFsZGFwOi8v
# L0NOPUJDUCUyMEdyb3VwJTIwSXNzdWluZyUyMENBJTIwMDEsQ049QUlBLENOPVB1
# YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRp
# b24sREM9YmNwY29ycCxEQz1uZXQ/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENs
# YXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQADggEBACbH
# tjOKXjmSGSNKmIp90ImFELKeAxEvaxvRkccarF0hInsTrsMXTnuabr0hk5yIpeqF
# YfAuk/CIJICLihitTYOuZ2l4EX/u3/Zy+wuMTGQep4dhkWt+aUpdwHsItNVnzggD
# IyQmYVlRf32PmDD548+nwdyL5M4a70ZgpEYURFfNj0eK/bts1Dic06rjHgMPblCQ
# 3YAy8YTEQeH6QQaXh0hz99tju7yPZ6FoYnhFPNpVdZa1Q8q1G5nF2Jjt+j1ODfKl
# R4GTXO1KOtrVwMUiPJMspYp8EL9Xo8OJKEdVIm76zz10dalk8O4LvKbAjOZj/NWo
# jBT9XALjML5DAZxciGgwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0G
# CSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0
# IFRydXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBp
# bmcgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJ
# UVXHJQPE8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+e
# DzMfUBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47q
# UT3w1lbU5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL
# 6IRktFLydkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c
# 1eYbqMFkdECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052
# FVUmcJgmf6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+
# onP65x9abJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/w
# ojzKQtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1
# eSuo80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uK
# IqjBJgj5FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7p
# XcheMBK9Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgw
# FoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7
# x1Bd4ksp+3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGId
# DAiCqBa9qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7g
# iqzl/Yy8ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6
# wCeCRK6ZJxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx
# 2cYTgAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5kn
# LD0/a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3it
# TK37xJV77QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7
# HhmLNriT1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUV
# mDG0YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKm
# KYcJRyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8
# MIIGwjCCBKqgAwIBAgIQBUSv85SdCDmmv9s/X+VhFjANBgkqhkiG9w0BAQsFADBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5n
# IENBMB4XDTIzMDcxNDAwMDAwMFoXDTM0MTAxMzIzNTk1OVowSDELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSAwHgYDVQQDExdEaWdpQ2VydCBU
# aW1lc3RhbXAgMjAyMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKNT
# RYcdg45brD5UsyPgz5/X5dLnXaEOCdwvSKOXejsqnGfcYhVYwamTEafNqrJq3RAp
# ih5iY2nTWJw1cb86l+uUUI8cIOrHmjsvlmbjaedp/lvD1isgHMGXlLSlUIHyz8sH
# pjBoyoNC2vx/CSSUpIIa2mq62DvKXd4ZGIX7ReoNYWyd/nFexAaaPPDFLnkPG2ZS
# 48jWPl/aQ9OE9dDH9kgtXkV1lnX+3RChG4PBuOZSlbVH13gpOWvgeFmX40QrStWV
# zu8IF+qCZE3/I+PKhu60pCFkcOvV5aDaY7Mu6QXuqvYk9R28mxyyt1/f8O52fTGZ
# ZUdVnUokL6wrl76f5P17cz4y7lI0+9S769SgLDSb495uZBkHNwGRDxy1Uc2qTGaD
# iGhiu7xBG3gZbeTZD+BYQfvYsSzhUa+0rRUGFOpiCBPTaR58ZE2dD9/O0V6MqqtQ
# FcmzyrzXxDtoRKOlO0L9c33u3Qr/eTQQfqZcClhMAD6FaXXHg2TWdc2PEnZWpST6
# 18RrIbroHzSYLzrqawGw9/sqhux7UjipmAmhcbJsca8+uG+W1eEQE/5hRwqM/vC2
# x9XH3mwk8L9CgsqgcT2ckpMEtGlwJw1Pt7U20clfCKRwo+wK8REuZODLIivK8SgT
# IUlRfgZm0zu++uuRONhRB8qUt+JQofM604qDy0B7AgMBAAGjggGLMIIBhzAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAU
# uhbZbU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFKW27xPn783QZKHVVqllMaPe
# 1eNJMFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmww
# gZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAIEa1t6gqbWYF7xwjU+KPGic2CX/yyzkzepd
# IpLsjCICqbjPgKjZ5+PF7SaCinEvGN1Ott5s1+FgnCvt7T1IjrhrunxdvcJhN2hJ
# d6PrkKoS1yeF844ektrCQDifXcigLiV4JZ0qBXqEKZi2V3mP2yZWK7Dzp703DNiY
# dk9WuVLCtp04qYHnbUFcjGnRuSvExnvPnPp44pMadqJpddNQ5EQSviANnqlE0Pjl
# SXcIWiHFtM+YlRpUurm8wWkZus8W8oM3NG6wQSbd3lqXTzON1I13fXVFoaVYJmoD
# Rd7ZULVQjK9WvUzF4UbFKNOt50MAcN7MmJ4ZiQPq1JE3701S88lgIcRWR+3aEUuM
# MsOI5ljitts++V+wQtaP4xeR0arAVeOGv6wnLEHQmjNKqDbUuXKWfpd5OEhfysLc
# PTLfddY2Z1qJ+Panx+VPNTwAvb6cKmx5AdzaROY63jg7B145WPR8czFVoIARyxQM
# fq68/qTreWWqaNYiyjvrmoI1VygWy2nyMpqy0tg6uLFGhmu6F/3Ed2wVbK6rr3M6
# 6ElGt9V/zLY4wNjsHPW2obhDLN9OTH0eaHDAdwrUAuBcYLso/zjlUlrWrBciI070
# 7NMX+1Br/wd3H3GXREHJuEbTbDJ8WC9nR2XlG3O2mflrLAZG70Ee8PBf4NvZrZCA
# RK+AEEGKMYIFLDCCBSgCAQEwZzBQMRMwEQYKCZImiZPyLGQBGRYDbmV0MRcwFQYK
# CZImiZPyLGQBGRYHYmNwY29ycDEgMB4GA1UEAxMXQkNQIEdyb3VwIElzc3Vpbmcg
# Q0EgMDECEyAAA8dXa19g3wT7F4kAAQADx1cwCQYFKw4DAhoFAKB4MBgGCisGAQQB
# gjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFOGF3BqZ
# l2uDRm1suEbkFDJ2hf6lMA0GCSqGSIb3DQEBAQUABIIBALphpFBl+WcTmSiY6wF8
# RZ55b33iv+7l0fm5v44QR1dVrG69GLfPkPRf9QG6kyrwaCMq6Bx++PAqdKzF04QA
# 5Kkw7iozCUFVeEnWrkj5YWXIXlrPP9VDYUb/eaJpH99ZvzKGs9zawZ3co5eizpmg
# +TEoRn3Z/RIiYKuBj1xexEkfpnsGO01HgcaoagHC7+aPDzde3Kfi6BOY3uqOThYQ
# 2vKNo9D3RwzFYKHjKLEV060V68Sg/wi6Vf6BW743Tedw50D2LUJxrNyjVKOixuV0
# Mg8XP2qH7Lo5DTkjwtWgIhvExi636W7kVZeLRjlqIlgm3yv/EaojPSO5Me2BeNE0
# xM2hggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRy
# dXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0I
# Oaa/2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMjQwOTEzMTM1MDU5WjAvBgkqhkiG9w0BCQQx
# IgQgKueLRgMBZmCXzms0KgXDB1rAI4HNiKQkTdfjTi+qq2UwDQYJKoZIhvcNAQEB
# BQAEggIAEUvVYaTvsy4HdLBAfnUS3B2zjy8053umrDAiacXJjA+iQTNaZbjxjSGd
# 9ogZkLL3tsvCsQKBVEKxDl7wBW4iqHxf6ybbPqv1qeSKqgt1oLjsK9xa5IegY1uh
# /D3DtLnbiOXmjmNgxDzSrItuP5ZVeHJ1LolezL88fijh6y7PtX6CG+3J8y6fenSB
# BryL23TJ9UEYbr0BPYdW2VWXcdetHLzQlLEOgQlZmdbIJBu/K4yIlRy0Y2cFNtqx
# bu0TxtQGn0aZ2+5NIJfVDO4ohE11qIJZdyMWp+El5bCbyNlVCR0XMc5UjPOxC91b
# Yi/eiwXALWLZivM9QCizfoDVDgTtF1Uqta42m9VgB7b4B2BnZNuTKgN1bwxkIBiW
# Eviw+4Sh6V9RpYWWTcyZxwl1yLZnlY5oMklDzZgCULpJGm3+/8gj5eCf1Ed5Qqil
# nYTfzfiV+G4xOH5eLPVYwRXlKybu0uh0wqpUiQPBpE9zqzV7u4euYfCfqCWnOTan
# xY8M8JL6Iao/r2f92arvYoljDaRumqnXAtNncRHfjF2AW99Lmh2fSDFls445Yskt
# psoz9g428m35u+EmlheVg6XeQv/85TEgAYrVy9/gDrMicie0uT9MGrgtyi8MtlvV
# 8+MMz1tknMuM01Du3EgO941qpH/kCmnxOoXQ07CFJt8q1JcyDck=
# SIG # End signature block
