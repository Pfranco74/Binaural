$scriptVersion = "20241007"

# Logging Function
function global:Write-CMLogEntry {
	param (
		[parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
		[ValidateNotNullOrEmpty()]
		[string]
		$Value,
		#[parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
		#[ValidateNotNullOrEmpty()]
		#[ValidateSet("1", "2", "3")]
		#[string]
		#$Severity,
		#[parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
		#[ValidateNotNullOrEmpty()]
		[string]
		$FileName = "Script_Run_UpdateDrivers.log"
	)

	# Determine log file location
	$LogFilePath = Join-Path -Path $LogDir -ChildPath $FileName
	# Construct time stamp for log entry
	$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
	# Construct date for log entry
	$Date = (Get-Date -Format "MM-dd-yyyy")
	# Construct context for log entry
	$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	# Construct final log entry
	$LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"""
	# Add value to log file
	try {
		Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop
	}
	catch [System.Exception] {
		Write-Warning -Message "Unable to append log entry to Invoke-DriverUpdate.log file. Error message: $($_.Exception.Message)"
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

    $msg = "Computer Model is " + $Model
    Write-CMLogEntry -Value $msg


    Return $Model  
}

function OSVersion
{
    
    $checkVersion = (((Get-WmiObject -Class Win32_OperatingSystem).caption).split(" "))[2]

    #$CheckVersion = (Get-WmiObject -Class Win32_OperatingSystem).caption -match "Windows 10"
    #if ($CheckVersion -eq $true)
    #{
    #    $OperVersion = "10"
    #}

    #$CheckVersion = (Get-WmiObject -Class Win32_OperatingSystem).caption -match "Windows 11"
    #if ($CheckVersion -eq $true)
    #{
    #    $OperVersion = "11"
    #}

    $msg = "Operating system version is " + $OperVersion
    Write-CMLogEntry -Value $msg

    #Return $OperVersion
    Return $checkVersion
}

function CopyFiles
{
    try
    {        
        $SourcePath = Join-Path -Path .\files -ChildPath "${Model}_Win$($OSversion).xml"    
    
        if (-not(Test-Path $SourcePath))
        {                 
            $msg = "Local XML File not found " + $SourcePath
            Write-CMLogEntry -Value $msg
            ForceErr    
        }    
        
        Write-Host "Start copying files"
        Copy-Item -Path .\Files\*.* -Destination $Repo -Force
        
        $msg = "Copy XML control file"
        Write-CMLogEntry -Value $msg

    }
    catch
    {
        Write-Host "Error copying files" -ForegroundColor Red

        $msg = "Error copying files"
        Write-CMLogEntry -Value $msg
        
        ForceErr
    }
}

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

function LocalXml
{   
    $ModelXmlPath = Join-Path -Path $Repo -ChildPath "${Model}_Win$($OSversion).xml"
    if (-not (Test-Path $ModelXmlPath))
    {                 
        $msg = "Local XML File not found " + $ModelXmlPath
        Write-CMLogEntry -Value $msg
        ForceErr
    }

    $COMPUTERXML = Get-Content -LiteralPath $ModelXmlPath -Raw
    [xml]$PARSEDModelXML = $COMPUTERXML -replace "^$UTF8ByteOrderMark"

    # Get and save XML Driver information
    Write-Host "Get and save XML Driver information"

    $msg = "Get and save XML Driver information"
    Write-CMLogEntry -Value $msg


    foreach ($Package in $PARSEDModelXML.packages.package) 
    {
        if (($Package.category -like "*BIOS*"))
        {
            
            $Filename = ($Package.location).Split("/")[-1]
            $SaveFile = Join-Path $WebRepo -ChildPath $Filename
            
            
            $filename = $Package.location.Substring($Package.location.LastIndexOf("/") + 1)
            $separatorIndex = $filename.IndexOf('.')
            $packageID = $filename.Substring(0, $separatorIndex - 3)
            $urlsite = $SaveFile.Replace(".xml",".url")
            Out-File -FilePath $urlsite -InputObject $Package.location
                        
            $msg = "Save Driver XML file" + $SaveFile
            Write-CMLogEntry -Value $msg
            Invoke-WebRequest -Uri $Package.location -OutFile $SaveFile        
        }
    }
    
    Return [xml]$PARSEDModelXML
}

function CompareBios ($WebVerion)
{    
    $Biosupdate = $true    
    $bioslocalversion = ((Get-ItemProperty -Path HKLM:\HARDWARE\DESCRIPTION\System\BIOS -Name Biosversion).biosversion).toupper()

    if ($bioslocalversion.Contains(" "))
    {
        $bioslocalversion = $bioslocalversion.Split(" ")[0]
    }
    
    
    $bioswebversion = $WebVerion.toupper()

    if ($bioslocalversion -eq $bioswebversion)
    {
        $Biosupdate = $false
        $msg = "Same bios version"
        Write-Host $msg
        Write-CMLogEntry -Value $msg 
        return $Biosupdate
    }
}

function WebXml
{   
    $RunBios = $True
    $XmlList = Get-ChildItem -Path $WebRepo -Filter *.xml
    foreach ($file in $XmlList)
    {
        $Msg = "Process File " +  $file.FullName    
        Write-Host $msg
        Write-CMLogEntry -Value $msg      

        $collection = $null
        [xml]$xmlfile = Get-Content -Path $file.FullName  
        $urlfile = $file.fullName.Replace(".xml",".url") 
        $url = Get-Content -Path $urlfile
        $__url = $url.SubString(0, $url.LastIndexOf('/') + 1) 
        $WebVersion = $xmlfile.Package.version
        $NeedtoRun = CompareBios $WebVersion

        if ($NeedtoRun -eq $false)
        {
            $RunBios = $False
            $msg = "Same Bios Version Skiping Update"
            Write-Host $msg
            Write-CMLogEntry -Value $msg      
            Return $RunBios
        }


        # Dowload Driver

        $DriverDir = Join-Path -Path $WebRepo -ChildPath $xmlfile.Package.id
        CreateDir $DriverDir

        $msg = "Get files for downloading..."
        Write-Host $msg
        Write-CMLogEntry -Value $msg      
    
        try
        {
            $installerFile = $xmlfile.GetElementsByTagName("Files").GetElementsByTagName("Installer").GetElementsByTagName("File")
        }
        catch
        {
            Write-LogInformation("No installer file specified.")
            ForceErr
        }

        try
        {
            $ReadmeFile = $xmlfile.GetElementsByTagName("Files").GetElementsByTagName("Readme").GetElementsByTagName("File")
        }
        catch
        {
            Write-LogInformation("No readme file specified.")
            ForceErr
        }

        $fileNameElements = $null
        if ($installerFile) { $fileNameElements += $installerFile }
        if ($ReadmeFile) { $fileNameElements += $ReadmeFile }

    
        foreach ($element in $fileNameElements)
        {
            $filename = $element.GetElementsByTagName("Name").InnerText
            $expectedFileSize = $element.GetElementsByTagName("Size").InnerText
            $expectedFileCRC = $element.GetElementsByTagName("CRC").InnerText

            $fileUrl = $__url + $filename
            $fileUrlDestination = Join-Path $DriverDir -ChildPath $filename
            Invoke-WebRequest -Uri $fileUrl -OutFile $fileUrlDestination
        }
    }
}

function Extract
{
    $msg = "Start extracting driver" 
    Write-CMLogEntry -Value $msg   
    
    $list = Get-ChildItem -Path $WebRepo -Directory   
    
    foreach ($item in $list)
    {
        $file = Get-ChildItem $item.FullName -File -Filter *.exe
        foreach ($item1 in $file)
        {
            $updatedir = $item1.DirectoryName
            $updatedirextract = Join-Path -Path $updatedir -ChildPath "Extract"
            CreateDir $updatedirextract
            $argumentos = "/verysilent /dir=" + $updatedirextract
            $run = Start-Process -FilePath $item1.FullName -ArgumentList $argumentos -NoNewWindow -PassThru
            Start-Sleep -Seconds 13
            Get-Process -Name wFlashGUIx | Stop-Process -ErrorAction SilentlyContinue
            Get-Process -Name winuptp | Stop-Process -ErrorAction SilentlyContinue
        }
    }
}

function InstallDriver
{
    $msg = "Start Install Bios Function" 
    Write-CMLogEntry -Value $msg   
    Write-Host "Start Install Bios Function" 

    $list = Get-ChildItem -Path $WebRepo -Directory   
    
    foreach ($item in $list)
    {
        $extractfolder = $WebRepo + "\" + $item.Name + "\Extract"

        if ((Test-Path $extractfolder))
        {
            $reboot = "1641"
            $wFlash = $extractfolder + "\wFlashGUIx64.exe"
            $winuptp = $extractfolder + "\winuptp.exe"
            $winuptplog = $extractfolder + "\winuptp.log"

            if ((Test-Path $wFlash))
            {
                $msg = "Update Bios trough Wflash" 
                Write-CMLogEntry -Value $msg   

                Set-Location $extractfolder
                $argumentos = "/quiet"               
                $run = Start-Process -FilePath $wFlash -ArgumentList $argumentos -Wait -NoNewWindow -PassThru
                if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010) -and ($run.ExitCode -ne 1641))
                {    
                    Write-host "$Error[0]"
                    ForceErr
                }  
                Return $reboot 
            }

            if ((Test-Path $winuptp))
            {
                $msg = "Update Bios trough winuptp" 
                Write-CMLogEntry -Value $msg   


                Set-Location $extractfolder
                $argumentos = "-s"
                $run = Start-Process -FilePath $winuptp -ArgumentList $argumentos -Wait -NoNewWindow -PassThru
                if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010) -and ($run.ExitCode -ne 1641) -and ($run.ExitCode -ne 1))
                {   
                    write-host "Error appling Update"
                    $msg = "Error appling Update"
                    Write-CMLogEntry -Value $msg 
                    $winuptplogerr = get-content -Path $winuptplog 
                    write-host $winuptplogerr
                    Write-host "$Error[0]"
                    ForceErr
                }
                
                copy-item -Path $winuptplog -Destination $LogDir -Force -ErrorAction SilentlyContinue
                Return $reboot
            }

            $msg = "Check Bios Update Launcher" 
            Write-CMLogEntry -Value $msg  
            write-host "Check Bios Update Launcher"  
            ForceErr
        }
        Else
        {
            $msg = "Extract Folder not found"
            Write-CMLogEntry -Value $msg   
            ForceErr
        }

        
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
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\Lenovo_Bios_Update.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\Lenovo_Bios_Update\PS_Lenovo_Bios_Update.log"
$LogErr = "C:\Windows\Temp\Logs\Lenovo_Bios_Update\PS_Lenovo_Bios_Update.nok"
$LogDir = "C:\Windows\Temp\Logs\Bios\Lenovo_Bios_Update"
$WebRepo = "C:\Windows\Temp\Bios\Lenovo\WebRepo"
$Repo = "C:\Windows\Temp\Bios\Lenovo\LocalRepo"

CreateDir $LogDir
CreateDir $DirAuto
CreateDir $WebRepo
CreateDir $Repo

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion

$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now


Write-Host "Start Bios Update Process"

$msg = "Start Bios Update Process"
Write-CMLogEntry -Value $msg

try
{
    $Manufacturer = Manufacturer

    if ($Manufacturer -ne 'LENOVO')
    {
        Write-Output "Skip Update not Lenovo Model"
        $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
        AutoPilot "End  " $now
        Stop-Transcript
        exit 0
    }
}
catch
{
    $msg = "Error getting manufacturer"
    Write-CMLogEntry -Value $msg
    Write-host "$Error[0]"
    ForceErr  
}

$reboot = "0"

#Get Computer Model
$model = ComputerModel
Write-Host "Lenovo Model is: $Model"

#Get Os Version
$OSversion = OSVersion
Write-Host "Operation System Version is: $OSversion"

#Get Model Web XML
Write-host "Download Model XML from Web"
try
{
    $modelurl = "download.lenovo.com/catalog/" + $model + "_Win" + $OSversion + ".xml"
    $modelurldest = Join-Path -Path $Repo -ChildPath "${Model}_Win$($OSversion).xml"

    Invoke-WebRequest -Uri $modelurl -OutFile $modelurldest
}
catch
{
    $msg = "Error download $modelurl"
    Write-CMLogEntry -Value $msg
    Write-host "$Error[0]"
    ForceErr  
}

# Process local XML Driver Model
Write-Host "Process local XML Driver Model"
$msg = "Process local XML Driver Model"
Write-CMLogEntry -Value $msg      

[xml]$PARSEDModelXML = LocalXml


# Get all drivers information
Write-Host "Get all web drivers information"
$msg = "Get all web drivers information"
Write-CMLogEntry -Value $msg      

$Run = WebXml

if ($Run -eq $false)
{
    write-host "Nothing to do"
    $msg = "Nothing to do"
    Write-CMLogEntry -Value $msg   
    $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
    AutoPilot "End  " $now
    $intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
    Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
    Stop-Transcript
    exit 0
}
else
{
    # Extract Driver   
    write-host "Extract Driver"
    $msg = "Start Extract Driver Process"
    Write-CMLogEntry -Value $msg      

    Extract
  

    # Install Bios
    write-host "Start Install Bios Update "
    $msg = "Start Install Bios Update"
    Write-CMLogEntry -Value $msg    
    $forceReboot = InstallDriver
}    
    
$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "End  " $now
$intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue

Stop-Transcript

exit $forceReboot


# SIG # Begin signature block
# MIIfPAYJKoZIhvcNAQcCoIIfLTCCHykCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUy2qaSJBA4FvdlheufON1qIFJ
# LqSgghl6MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
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
# MIIGvDCCBKSgAwIBAgIQC65mvFq6f5WHxvnpBOMzBDANBgkqhkiG9w0BAQsFADBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5n
# IENBMB4XDTI0MDkyNjAwMDAwMFoXDTM1MTEyNTIzNTk1OVowQjELMAkGA1UEBhMC
# VVMxETAPBgNVBAoTCERpZ2lDZXJ0MSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3Rh
# bXAgMjAyNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL5qc5/2lSGr
# ljC6W23mWaO16P2RHxjEiDtqmeOlwf0KMCBDEr4IxHRGd7+L660x5XltSVhhK64z
# i9CeC9B6lUdXM0s71EOcRe8+CEJp+3R2O8oo76EO7o5tLuslxdr9Qq82aKcpA9O/
# /X6QE+AcaU/byaCagLD/GLoUb35SfWHh43rOH3bpLEx7pZ7avVnpUVmPvkxT8c2a
# 2yC0WMp8hMu60tZR0ChaV76Nhnj37DEYTX9ReNZ8hIOYe4jl7/r419CvEYVIrH6s
# N00yx49boUuumF9i2T8UuKGn9966fR5X6kgXj3o5WHhHVO+NBikDO0mlUh902wS/
# Eeh8F/UFaRp1z5SnROHwSJ+QQRZ1fisD8UTVDSupWJNstVkiqLq+ISTdEjJKGjVf
# IcsgA4l9cbk8Smlzddh4EfvFrpVNnes4c16Jidj5XiPVdsn5n10jxmGpxoMc6iPk
# oaDhi6JjHd5ibfdp5uzIXp4P0wXkgNs+CO/CacBqU0R4k+8h6gYldp4FCMgrXdKW
# fM4N0u25OEAuEa3JyidxW48jwBqIJqImd93NRxvd1aepSeNeREXAu2xUDEW8aqzF
# QDYmr9ZONuc2MhTMizchNULpUEoA6Vva7b1XCB+1rxvbKmLqfY/M/SdV6mwWTyeV
# y5Z/JkvMFpnQy5wR14GJcv6dQ4aEKOX5AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8E
# BAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNV
# HSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2F
# L3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFJ9XLAN3DigVkGalY17uT5IfdqBbMFoG
# A1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsG
# AQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJ
# KoZIhvcNAQELBQADggIBAD2tHh92mVvjOIQSR9lDkfYR25tOCB3RKE/P09x7gUsm
# Xqt40ouRl3lj+8QioVYq3igpwrPvBmZdrlWBb0HvqT00nFSXgmUrDKNSQqGTdpjH
# sPy+LaalTW0qVjvUBhcHzBMutB6HzeledbDCzFzUy34VarPnvIWrqVogK0qM8gJh
# h/+qDEAIdO/KkYesLyTVOoJ4eTq7gj9UFAL1UruJKlTnCVaM2UeUUW/8z3fvjxhN
# 6hdT98Vr2FYlCS7Mbb4Hv5swO+aAXxWUm3WpByXtgVQxiBlTVYzqfLDbe9PpBKDB
# fk+rabTFDZXoUke7zPgtd7/fvWTlCs30VAGEsshJmLbJ6ZbQ/xll/HjO9JbNVekB
# v2Tgem+mLptR7yIrpaidRJXrI+UzB6vAlk/8a1u7cIqV0yef4uaZFORNekUgQHTq
# ddmsPCEIYQP7xGxZBIhdmm4bhYsVA6G2WgNFYagLDBzpmk9104WQzYuVNsxyoVLO
# bhx3RugaEGru+SojW4dHPoWrUhftNpFC5H7QEY7MhKRyrBe7ucykW7eaCuWBsBb4
# HOKRFVDcrZgdwaSIqMDiCLg4D+TPVgKx2EgEdeoHNHT9l3ZDBD+XgbF+23/zBjeC
# txz+dL/9NWR6P2eZRi7zcEO1xwcdcqJsyz/JceENc2Sg8h3KeFUCS7tpFk7CrDqk
# MYIFLDCCBSgCAQEwZzBQMRMwEQYKCZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPy
# LGQBGRYHYmNwY29ycDEgMB4GA1UEAxMXQkNQIEdyb3VwIElzc3VpbmcgQ0EgMDEC
# EyAAA8dXa19g3wT7F4kAAQADx1cwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFD9L34BN+ShslTnv
# awMLMBF9ULrhMA0GCSqGSIb3DQEBAQUABIIBADpwS+quzIdY2E0pMHLaFnpqxHfq
# HZ1bn2drjagA6KxnTZxX1RoAOY6jgqNBH3CnMPBD1ElQvJfapZ40P4yC5FLr9Rb4
# 9Mj7A34u89aWIgawlPsTHTXcHRI5mh5mI+11q//H96hyYV9mwE2WPCvBTfLiV9Dx
# UAjIipktyN61UWu/0X1NS1gs7c9xmR0n3mBQzr7UWvlIdzN8+pMtuhZAAnitIgqc
# 4/AOV7MwwcgX4Uh0Q1QwQwctcpebOB64SedjX/fkWGduq9eDr4n1xhlmHl9ZHcQx
# lalezXibt6smqtIeYv0/qKQWDkt2Z4lB3o7wrhzaW3UOE2N50x+dUYYtVMChggMg
# MIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQg
# RzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/lYfG+ekE
# 4zMEMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAc
# BgkqhkiG9w0BCQUxDxcNMjQxMDA3MTUwMzI1WjAvBgkqhkiG9w0BCQQxIgQgzmpr
# e/Qu8/GeUI/QM4lCHJ/q8h0znk63XWuMqjmtCQkwDQYJKoZIhvcNAQEBBQAEggIA
# m3fpT2o4gJTz0/nMJdBXDwgfUEiAodF8b5D2LPZHPolfTHNwiBe+UQdED1apVpzp
# sh9xsnK8cawEw979W3+J8wWMJkZiTSA6xFCppTB94aIK8OUugAArQqG4Bck5QtUN
# fKl9A15qP+cpvPX4LzeVg23lBIPdw/aeiWty0xzP1RJjEYurC7aWM4NpnG4r2f6d
# EuHOrMy1I41TL7XNCK7YO3dR0fRlrf3Whfor/eDvtC9G9WqARc/oBFqMkvJ49BRS
# 5aVSjgYOSqNCc6agOA8TNJ0eUOphopPp280krzuC/kH9NWXHnvlXU1Og9Guupold
# 9eBkYxI2KJV8ZFk+8DdPVnewn51SG0iAvyw9JoiLgjCPFwWQQKp5utCjvHwlsi+U
# Q3U+f9F6hWNPSSvmUek1PU+dkxaVynOWbINUY+aTS/0X9FZeGBpa4u6vTcjt34lQ
# nQsFi03N7nXKe05eXs12/UIHGqxpMFTadme4OAv9kq5TmOZ6Vwr9TIYog+0KnJQO
# DKXB6ezVtNUBVON6Tuh0uZmrw5r7LOxf/ENJCVWKZaYAJFCaDIlR7AT0BbuybMm7
# gS7Xze93NsChVYhdsgTCa+3RmhIX0ruCNjXVHZXGQXOOg91s5u66wYNCdLg8kxOM
# DaQ9kAmbMqvj0dt8TOQ30lPWjJL8Dek3fAs2wgLzgVk=
# SIG # End signature block
