# // =================== GLOBAL VARIABLES ====================== //


# Set Temp & Log Location
[string]$TempDirectory = "C:\Windows\Temp\Drivers"
[string]$LogDirectory = "C:\Windows\Temp\Logs\Drivers"

# Create Temp Folder 
if ((Test-Path -Path $TempDirectory) -eq $false) {
	New-Item -Path $TempDirectory -ItemType Dir
}

# Create Logs Folder 
if ((Test-Path -Path $LogDirectory) -eq $false) {
	New-Item -Path $LogDirectory -ItemType Dir
}

# Logging Function
function global:Write-CMLogEntry {
	param (
		[parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
		[ValidateNotNullOrEmpty()]
		[string]
		$Value,
		[parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("1", "2", "3")]
		[string]
		$Severity,
		[parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
		[ValidateNotNullOrEmpty()]
		[string]
		$FileName = "Script_Run_UpdateDrivers.log"
	)

	# Determine log file location
	$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $FileName
	# Construct time stamp for log entry
	$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
	# Construct date for log entry
	$Date = (Get-Date -Format "MM-dd-yyyy")
	# Construct context for log entry
	$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	# Construct final log entry
	$LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""DriverAutomationScript"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	# Add value to log file
	try {
		Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop
	}
	catch [System.Exception] {
		Write-Warning -Message "Unable to append log entry to Invoke-DriverUpdate.log file. Error message: $($_.Exception.Message)"
	}
}

Start-Transcript "C:\Windows\Temp\Logs\Drivers\UpdateDrivers.log"


# // =================== DELL VARIABLES ================ //

# Define Dell Download Sources
$DellDownloadList = "http://downloads.dell.com/published/Pages/index.html"
$DellDownloadBase = "http://downloads.dell.com"
$DellDriverListURL = "http://en.community.dell.com/techcenter/enterprise-client/w/wiki/2065.dell-command-deploy-driver-packs-for-enterprise-client-os-deployment"
$DellBaseURL = "http://en.community.dell.com"

# Define Dell Download Sources
$DellXMLCabinetSource = "http://downloads.dell.com/catalog/DriverPackCatalog.cab"
$DellCatalogSource = "http://downloads.dell.com/catalog/CatalogPC.cab"

# Define Dell Cabinet/XL Names and Paths
$DellCabFile = [string]($DellXMLCabinetSource | Split-Path -Leaf)
$DellCatalogFile = [string]($DellCatalogSource | Split-Path -Leaf)
$DellXMLFile = $DellCabFile.Trim(".cab")
$DellXMLFile = $DellXMLFile + ".xml"
$DellCatalogXMLFile = $DellCatalogFile.Trim(".cab") + ".xml"

# Define Dell Global Variables
$DellCatalogXML = $null
$DellModelXML = $null
$DellModelCabFiles = $null

# // =================== HP VARIABLES ================ //

# Define HP Download Sources
$HPXMLCabinetSource = "http://ftp.hp.com/pub/caps-softpaq/cmit/HPClientDriverPackCatalog.cab"
$HPSoftPaqSource = "http://ftp.hp.com/pub/softpaq/"
$HPPlatFormList = "http://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/ref/platformList.cab"

# Define HP Cabinet/XL Names and Paths
$HPCabFile = [string]($HPXMLCabinetSource | Split-Path -Leaf)
$HPXMLFile = $HPCabFile.Trim(".cab")
$HPXMLFile = $HPXMLFile + ".xml"
$HPPlatformCabFile = [string]($HPPlatFormList | Split-Path -Leaf)
$HPPlatformXMLFile = $HPPlatformCabFile.Trim(".cab")
$HPPlatformXMLFile = $HPPlatformXMLFile + ".xml"

# Define HP Global Variables
$global:HPModelSoftPaqs = $null
$global:HPModelXML = $null
$global:HPPlatformXML = $null
$global:Drvlist = $null


# // =================== LENOVO VARIABLES ================ //

# Define Lenovo Download Sources
$global:LenovoXMLSource = "https://download.lenovo.com/cdrt/td/catalog.xml"

# Define Lenovo Cabinet/XL Names and Paths
$global:LenovoXMLFile = [string]($global:LenovoXMLSource | Split-Path -Leaf)

# Define Lenovo Global Variables
$global:LenovoModelDrivers = $null
$global:LenovoModelXML = $null
$global:LenovoModelType = $null
$global:LenovoSystemSKU = $null

# // =================== COMMON VARIABLES ================ //

# Determine manufacturer
$ComputerManufacturer = (Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer).Trim()
Write-CMLogEntry -Value "Manufacturer determined as: $($ComputerManufacturer)" -Severity 1

# Determine manufacturer name and hardware information
switch -Wildcard ($ComputerManufacturer) {
	"*HP*" {
		$ComputerManufacturer = "Hewlett-Packard"
		$ComputerModel = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
		$SystemSKU = (Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI).BaseBoardProduct
	}
	"*Hewlett-Packard*" {
		$ComputerManufacturer = "Hewlett-Packard"
		$ComputerModel = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
		$SystemSKU = (Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI).BaseBoardProduct
	}
	"*Dell*" {
		$ComputerManufacturer = "Dell"
		$ComputerModel = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
		$SystemSKU = (Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI).SystemSku
	}
	"*Lenovo*" {
		$ComputerManufacturer = "Lenovo"
		$ComputerModel = Get-WmiObject -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty Version
		$SystemSKU = ((Get-CIMInstance -ClassName MS_SystemInformation -NameSpace root\WMI | Select-Object -ExpandProperty BIOSVersion).SubString(0, 4)).Trim()
	}
}
Write-CMLogEntry -Value "Computer model determined as: $($ComputerModel)" -Severity 1

if (-not [string]::IsNullOrEmpty($SystemSKU)) {
	Write-CMLogEntry -Value "Computer SKU determined as: $($SystemSKU)" -Severity 1
}

# Get operating system name from version
switch -wildcard (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version) {
	"10.0*" {
		$OSName = "Windows 10"
	}
	"11.0*" {
		$OSName = "Windows 11"
	}
}
Write-CMLogEntry -Value "Operating system determined as: $OSName" -Severity 1


# Get Build operating system name from version
switch -wildcard (Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Version) {
	"10.0.19045" {
		$Build = "22H2"
	}
	"11.0*" {
		$Build = "22h2"
	}
}
Write-CMLogEntry -Value "Operating Build determined as: $Build" -Severity 1

# Get operating system architecture
switch -wildcard ((Get-CimInstance Win32_operatingsystem).OSArchitecture) {
	"64-*" {
		$OSArchitecture = "64-Bit"
	}
	"32-*" {
		$OSArchitecture = "32-Bit"
	}
}

Write-CMLogEntry -Value "Architecture determined as: $OSArchitecture" -Severity 1

$WindowsVersion = ($OSName).Split(" ")[1]

function DownloadDriverList {
	global:Write-CMLogEntry -Value "======== Download Model Link Information ========" -Severity 1
	if ($ComputerManufacturer -eq "Hewlett-Packard") {
		if ((Test-Path -Path $TempDirectory\$HPCabFile) -eq $false) {
			global:Write-CMLogEntry -Value "======== Downloading HP Product List ========" -Severity 1
			# Download HP Model Cabinet File
			global:Write-CMLogEntry -Value "Info: Downloading HP driver pack cabinet file from $HPXMLCabinetSource" -Severity 1
			try {
				# Start-BitsTransfer -Source $HPXMLCabinetSource -Destination $TempDirectory
                Invoke-WebRequest -Uri $HPXMLCabinetSource  -OutFile $TempDirectory\$HPCabFile
				# Expand Cabinet File
				global:Write-CMLogEntry -Value "Info: Expanding HP driver pack cabinet file: $HPXMLFile" -Severity 1
				Expand "$TempDirectory\$HPCabFile" -F:* "$TempDirectory\$HPXMLFile"
			}
			catch {
				global:Write-CMLogEntry -Value "Error: $($_.Exception.Message)" -Severity 3
                Stop-Transcript
                exit 1001
			}
		}
		# Read XML File
		if ($global:HPModelSoftPaqs -eq $null) {
			global:Write-CMLogEntry -Value "Info: Reading driver pack XML file - $TempDirectory\$HPXMLFile" -Severity 1
			[xml]$global:HPModelXML = Get-Content -Path $TempDirectory\$HPXMLFile
			# Set XML Object
			$global:HPModelXML.GetType().FullName | Out-Null
			$global:HPModelSoftPaqs = $HPModelXML.NewDataSet.HPClientDriverPackCatalog.ProductOSDriverPackList.ProductOSDriverPack
		}
	}
	if ($ComputerManufacturer -eq "Dell") {
		if ((Test-Path -Path $TempDirectory\$DellCabFile) -eq $false) {
			global:Write-CMLogEntry -Value "Info: Downloading Dell product list" -Severity 1
			global:Write-CMLogEntry -Value "Info: Downloading Dell driver pack cabinet file from $DellXMLCabinetSource" -Severity 1
			# Download Dell Model Cabinet File
			try {
				Start-BitsTransfer -Source $DellXMLCabinetSource -Destination $TempDirectory
				# Expand Cabinet File
				global:Write-CMLogEntry -Value "Info: Expanding Dell driver pack cabinet file: $DellXMLFile" -Severity 1
				Expand "$TempDirectory\$DellCabFile" -F:* "$TempDirectory\$DellXMLFile"
			}
			catch {
				global:Write-CMLogEntry -Value "Error: $($_.Exception.Message)" -Severity 3
			}
		}
		if ($DellModelXML -eq $null) {
			# Read XML File
			global:Write-CMLogEntry -Value "Info: Reading driver pack XML file - $TempDirectory\$DellXMLFile" -Severity 1
			[xml]$DellModelXML = (Get-Content -Path $TempDirectory\$DellXMLFile)
			# Set XML Object
			$DellModelXML.GetType().FullName | Out-Null
		}
		$DellModelCabFiles = $DellModelXML.driverpackmanifest.driverpackage
		
	}
}


function Get-RedirectedUrl {
	Param (
		[Parameter(Mandatory = $true)]
		[String]
		$URL
	)
	
	$Request = [System.Net.WebRequest]::Create($URL)
	$Request.AllowAutoRedirect = $false
	$Request.Timeout = 3000
	$Response = $Request.GetResponse()
	
	if ($Response.ResponseUri) {
		$Response.GetResponseHeader("Location")
	}
	$Response.Close()
}


function InitiateDownloads {
	
	$Product = "Driver Automation"
	
	# Driver Download ScriptBlock
	$DriverDownloadJob = {
		Param ([string]
			$TempDirectory,
			[string]
			$ComputerModel,
			[string]
			$DriverCab,
			[string]
			$DriverDownloadURL
		)

		try {
			# Start Driver Download	
			Start-BitsTransfer -DisplayName "$ComputerModel-DriverDownload" -Source $DriverDownloadURL -Destination "$($TempDirectory + '\Driver Cab\' + $DriverCab)"
		}
		catch [System.Exception] {
			global:Write-CMLogEntry -Value "Error: $($_.Exception.Message)" -Severity 3
            Stop-Transcript
            exit 1002
		}
	}
	
	global:Write-CMLogEntry -Value "======== Starting Download Processes ========" -Severity 1
	global:Write-CMLogEntry -Value "Info: Operating System specified: Windows $($WindowsVersion)" -Severity 1
	global:Write-CMLogEntry -Value "Info: Operating System architecture specified: $($OSArchitecture)" -Severity 1
	
	# Operating System Version
	$OperatingSystem = ("Windows " + $($WindowsVersion))
	
	# Vendor Make
	$ComputerModel = $ComputerModel.Trim()
	
	# Get Windows Version Number
	switch -Wildcard ((Get-WmiObject -Class Win32_OperatingSystem).Version) {
		"*10.0.19045*" {
			$OSBuild = "22H2"
            $Operver = "W10"
		}
		"*10.0.15*" {
			$OSBuild = "1703"
		}
		"*10.0.14*" {
			$OSBuild = "1607"
		}
	}
	global:Write-CMLogEntry -Value "Info: Windows 10 build $OSBuild identified for driver match" -Severity 1
	
	# Start driver import processes
	global:Write-CMLogEntry -Value "Info: Starting Download,Extract And Import Processes For $ComputerManufacturer Model: $($ComputerModel)" -Severity 1
	
	# =================== DEFINE VARIABLES =====================
	
	if ($ComputerManufacturer -eq "Dell") {
		global:Write-CMLogEntry -Value "Info: Setting Dell variables" -Severity 1
		if ($DellModelCabFiles -eq $null) {
			[xml]$DellModelXML = Get-Content -Path $TempDirectory\$DellXMLFile
			# Set XML Object
			$DellModelXML.GetType().FullName | Out-Null
			$DellModelCabFiles = $DellModelXML.driverpackmanifest.driverpackage
		}
		if ($SystemSKU -ne $null) {
			global:Write-CMLogEntry -Value "Info: SystemSKU value is present, attempting match based on SKU - $SystemSKU)" -Severity 1
			
			$ComputerModelURL = $DellDownloadBase + "/" + ($DellModelCabFiles | Where-Object {
					((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.SystemID -eq $SystemSKU)
				}).delta
			$ComputerModelURL = $ComputerModelURL.Replace("\", "/")
			$DriverDownload = $DellDownloadBase + "/" + ($DellModelCabFiles | Where-Object {
					((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.SystemID -eq $SystemSKU)
				}).path
			$DriverCab = (($DellModelCabFiles | Where-Object {
						((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.SystemID -eq $SystemSKU)
					}).path).Split("/") | select -Last 1
		}
		elseif ($SystemSKU -eq $null -or $DriverCab -eq $null) {
			global:Write-CMLogEntry -Value "Info: Falling back to matching based on model name" -Severity 1
			
			$ComputerModelURL = $DellDownloadBase + "/" + ($DellModelCabFiles | Where-Object {
					((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.Name -like "*$ComputerModel*")
				}).delta
			$ComputerModelURL = $ComputerModelURL.Replace("\", "/")
			$DriverDownload = $DellDownloadBase + "/" + ($DellModelCabFiles | Where-Object {
					((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.Name -like "*$ComputerModel")
				}).path
			$DriverCab = (($DellModelCabFiles | Where-Object {
						((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.Name -like "*$ComputerModel")
					}).path).Split("/") | select -Last 1
		}
		$DriverRevision = (($DriverCab).Split("-")[2]).Trim(".cab")
		$DellSystemSKU = ($DellModelCabFiles.supportedsystems.brand.model | Where-Object {
				$_.Name -match ("^" + $ComputerModel + "$")
			} | Get-Unique).systemID
		if ($DellSystemSKU.count -gt 1) {
			$DellSystemSKU = [string]($DellSystemSKU -join ";")
		}
		global:Write-CMLogEntry -Value "Info: Dell System Model ID is : $DellSystemSKU" -Severity 1
	}

	if ($ComputerManufacturer -eq "Hewlett-Packard") {
		global:Write-CMLogEntry -Value "Info: Setting HP variables" -Severity 1
		if ($global:HPModelSoftPaqs -eq $null) {
			[xml]$global:HPModelXML = Get-Content -Path $TempDirectory\$HPXMLFile
			# Set XML Object
			$global:HPModelXML.GetType().FullName | Out-Null
			$global:HPModelSoftPaqs = $global:HPModelXML.NewDataSet.HPClientDriverPackCatalog.ProductOSDriverPackList.ProductOSDriverPack
		}
		if ($SystemSKU -ne $null) {
			$HPSoftPaqSummary = $global:HPModelSoftPaqs | Where-Object {
				($_.SystemID -match $SystemSKU) -and ($_.OSName -like "$OSName*$OSArchitecture*$OSBuild*")
			} | Sort-Object -Descending | select -First 1
		}
		else {
			$HPSoftPaqSummary = $global:HPModelSoftPaqs | Where-Object {
				($_.SystemName -match $ComputerModel) -and ($_.OSName -like "$OSName*$OSArchitecture*$OSBuild*")
			} | Sort-Object -Descending | select -First 1
		}
		if ($HPSoftPaqSummary -ne $null) {
			$HPSoftPaq = $HPSoftPaqSummary.SoftPaqID
			$HPSoftPaqDetails = $global:HPModelXML.newdataset.hpclientdriverpackcatalog.softpaqlist.softpaq | Where-Object {
				$_.ID -eq "$HPSoftPaq"
			}
			$ComputerModelURL = $HPSoftPaqDetails.URL
			# Replace FTP for HTTP for Bits Transfer Job
			$DriverDownload = ($HPSoftPaqDetails.URL).TrimStart("ftp:")
			$DriverCab = $ComputerModelURL | Split-Path -Leaf
			$DriverRevision = "$($HPSoftPaqDetails.Version)"
		}
		else{

            $manualxml = $TempDirectory + "\" + $operver + "_" + $OSBuild + "_" + $SystemSKU + ".xml"
        	if (Test-Path $manualxml)
            {
                $global:Drvlist = @()
                $controlspid = $null
                $readfile = Get-Content $manualxml
                
                foreach ($item in $readfile)
                {
                    if ($item -like "*UpdateInfo Supersedes*")
                    {
                        $driver = $false                       
                        $Filename = $null
                        $directoryname = $null
                        $Fileversion = $null
                        $spid = $null
                        $needdownload = $true

                        $spname=$item.Split("""")[1]
                    }

                    if ($item -like "*<ID>*")
                    {
                        $spid = $item.Split("<id>")[3]
                       
                    }
                    
                    if ($item -like "*<Name>*")
                    {
                        $spname = $item.Split("<>")[2]
                    }

                    if ($item -like "*SilentInstall*")
                    {
                        $SPswitch = $item.Split("<>")[2]
                    }

                    if ($item -like "*<Url>*")
                    {
                        $spdownload = $item.Split("<Url>")[5]
                    }

                    if ($item -like "*<Category>Driver*")
                    {
                        $driver = $true                       
                    }

                    if ($item -like "*<FileName>*")
                    {
                        $Filename=$ITEM.Split("<>")[2]                    
                    }

                    if ($item -like "*<Directory>*")
                    {
                        $directoryname=($ITEM.Split("<>")[2]).toupper()     
                    }

                    if ($item -like "*<Version>*")
                    {
                        $Fileversion=$ITEM.Split("<>")[2]                    
                    }

                    if ($item -like "*<OS>*")
                    {
                        $OsVerGet=$item.Split("<>")[2]
                        
                        if (($OsVerGet -like "*WT64_22H2*") -OR ($OsVerGet -like "*WTIOT64*"))
                        {
                            $Osver = $true      
                        }
                        else
                        {
                            $Osver = $false
                        }          
                    }
               
                        if (($Osver -eq $true) -and ($driver -eq $true))
                        {
                            $Osver = $false

                            if (($directoryname -like "*&LT;WINDIR&GT;*") -and ($needdownload -eq $true))
                            {
                                $directoryname = $directoryname.Replace("&LT;WINDIR&GT;","C:\Windows")
                                [string]$getfile = $directoryname + "\" + $Filename
                                if (Test-Path $getfile)
                                {
                                    $localfileversion = ((Get-ChildItem -Path $getfile).VersionInfo).fileversion

                                    if ($Fileversion -eq $localfileversion)
                                    {
                                        $msg = $spname + " " + $spid + " already installed"  
                                        Write-CMLogEntry -Value $msg -Severity 1
                                        $needdownload = $false
                                    }
                                }
                             
                            }


                            if (($directoryname -like "*&LT;WINSYSDIR&GT*") -and ($needdownload -eq $true))
                            {
                                $directoryname = $directoryname.Replace("&LT;WINSYSDIR&GT;","C:\Windows\System32")
                                [string]$getfile = $directoryname + "\" + $Filename
                                if (Test-Path $getfile)
                                {
                                    $localfileversion = ((Get-ChildItem -Path $getfile).VersionInfo).fileversion

                                    if ($Fileversion -eq $localfileversion)
                                    {
                                        $msg = $spname + " " + $spid + " already installed"  
                                        Write-CMLogEntry -Value $msg -Severity 1
                                        $needdownload = $false
                                    }

                                }
                             
                            }

                            if ($directoryname -like "*&LT;DRIVERS&GT*")
                            {
                                $directoryname = $directoryname.Replace("&LT;DRIVERS&GT;","C:\Windows\System32\drivers")
                                [string]$getfile = $directoryname + "\" + $Filename
                                if (Test-Path $getfile)
                                {
                                    $localfileversion = ((Get-ChildItem -Path $getfile).VersionInfo).fileversion

                                    if ($Fileversion -eq $localfileversion)
                                    {
                                        $msg = $spname + " " + $spid + " already installed"  
                                        Write-CMLogEntry -Value $msg -Severity 1
                                        $needdownload = $false
                                    }
                                }

                            }

                            if ($directoryname -like "*&LT;PROGRAMFILESDIR&GT;*")
                            {
                                $directoryname = $directoryname.Replace("&LT;PROGRAMFILESDIR&GT;","C:\Program Files")
                                [string]$getfile = $directoryname + "\" + $Filename
                             
                                if (Test-Path $getfile)
                                {
                                    $localfileversion = ((Get-ChildItem -Path $getfile).VersionInfo).fileversion

                                    if ($Fileversion -eq $localfileversion)
                                    {
                                        $msg = $spname + " " + $spid + " already installed"  
                                        Write-CMLogEntry -Value $msg -Severity 1
                                        $needdownload = $false
                                    }

                                }
                             
                            }

                            if ($directoryname -like "*&LT;PROGRAMFILESDIRX86&GT;*")
                            {
                                $directoryname = $directoryname.Replace("&LT;PROGRAMFILESDIRX86&GT;","C:\Program Files (x86)")
                                [string]$getfile = $directoryname + "\" + $Filename
                             
                                if (Test-Path $getfile)
                                {
                                    $localfileversion = ((Get-ChildItem -Path $getfile).VersionInfo).fileversion

                                    if ($Fileversion -eq $localfileversion)
                                    {                 
                                        $msg = $spname + " " + $spid + " already installed"  
                                        Write-CMLogEntry -Value $msg -Severity 1
                                        $needdownload = $false
                                    }
                                } 
                            }
                         
                            if ($needdownload -eq $true)
                            {
                                if ($controlspid -ne $spid)
                                {                                                                       
                                    $global:Drvlist += $spname + ";" + $spdownload + ";" + $spid+ ";" + $SPswitch
                                    $controlspid = $spid   
                                }
                            }
                        }
                    }
                }
            else
            {
                Write-CMLogEntry -Value "Unsupported model / operating system combination found. Exiting." -Severity 3
                Stop-Transcript
                exit 1003
            }            

		}
	}
	
	# Driver location variables
	$DriverSourceCab = ($TempDirectory + "\Driver Cab\" + $DriverCab)
	$DriverExtractDest = ("$TempDirectory" + "\Driver Files")
	global:Write-CMLogEntry -Value "Info: Driver extract location set - $DriverExtractDest" -Severity 1
	
	# =================== INITIATE DOWNLOADS ===================			
	
	global:Write-CMLogEntry -Value "======== $Product - $ComputerManufacturer $ComputerModel DRIVER PROCESSING STARTED ========" -Severity 1
	
	# =============== ConfigMgr Driver Cab Download =================				
	global:Write-CMLogEntry -Value "$($Product): Retrieving ConfigMgr driver pack site For $ComputerManufacturer $ComputerModel" -Severity 1
	global:Write-CMLogEntry -Value "$($Product): URL found: $ComputerModelURL" -Severity 1
	
	if (($ComputerModelURL -ne $null) -and ($DriverDownload -ne "badLink")) {
		# Cater for HP / Model Issue
		$ComputerModel = $ComputerModel -replace '/', '-'
		$ComputerModel = $ComputerModel.Trim()
		Set-Location -Path $TempDirectory
		# Check for destination directory, create if required and download the driver cab
		if ((Test-Path -Path $($TempDirectory + "\Driver Cab\" + $DriverCab)) -eq $false) {
			if ((Test-Path -Path $($TempDirectory + "\Driver Cab")) -eq $false) {
				New-Item -ItemType Directory -Path $($TempDirectory + "\Driver Cab")
			}
			global:Write-CMLogEntry -Value "$($Product): Downloading $DriverCab driver cab file" -Severity 1
			global:Write-CMLogEntry -Value "$($Product): Downloading from URL: $DriverDownload" -Severity 1
			Start-Job -Name "$ComputerModel-DriverDownload" -ScriptBlock $DriverDownloadJob -ArgumentList ($TempDirectory, $ComputerModel, $DriverCab, $DriverDownload)
			sleep -Seconds 5
			$BitsJob = Get-BitsTransfer | Where-Object {
				$_.DisplayName -match "$ComputerModel-DriverDownload"
			}
			while (($BitsJob).JobState -eq "Connecting") {
				global:Write-CMLogEntry -Value "$($Product): Establishing connection to $DriverDownload" -Severity 1
				sleep -seconds 30
			}
			while (($BitsJob).JobState -eq "Transferring") {
				if ($BitsJob.BytesTotal -ne $null) {
					$PercentComplete = [int](($BitsJob.BytesTransferred * 100)/$BitsJob.BytesTotal);
					global:Write-CMLogEntry -Value "$($Product): Downloaded $([int]((($BitsJob).BytesTransferred)/ 1MB)) MB of $([int]((($BitsJob).BytesTotal)/ 1MB)) MB ($PercentComplete%). Next update in 30 seconds." -Severity 1
					sleep -seconds 30
				}
				else {
					global:Write-CMLogEntry -Value "$($Product): Download issues detected. Cancelling download process" -Severity 2
					Get-BitsTransfer | Where-Object {
						$_.DisplayName -eq "$ComputerModel-DriverDownload"
					} | Remove-BitsTransfer
				}
			}
			Get-BitsTransfer | Where-Object {
				$_.DisplayName -eq "$ComputerModel-DriverDownload"
			} | Complete-BitsTransfer
			global:Write-CMLogEntry -Value "$($Product): Driver revision: $DriverRevision" -Severity 1
		}
		else {
			global:Write-CMLogEntry -Value "$($Product): Skipping $DriverCab. Driver pack already downloaded." -Severity 1
		}
		
		# Cater for HP / Model Issue
		$ComputerModel = $ComputerModel -replace '/', '-'
		
		if (((Test-Path -Path "$($TempDirectory + '\Driver Cab\' + $DriverCab)") -eq $true) -and ($DriverCab -ne $null)) {
			global:Write-CMLogEntry -Value "$($Product): $DriverCab File exists - Starting driver update process" -Severity 1
			# =============== Extract Drivers =================
			
			if ((Test-Path -Path "$DriverExtractDest") -eq $false) {
				New-Item -ItemType Directory -Path "$($DriverExtractDest)"
			}
			if ((Get-ChildItem -Path "$DriverExtractDest" -Recurse -Filter *.inf -File).Count -eq 0) {
				global:Write-CMLogEntry -Value "==================== $PRODUCT DRIVER EXTRACT ====================" -Severity 1
				global:Write-CMLogEntry -Value "$($Product): Expanding driver CAB source file: $DriverCab" -Severity 1
				global:Write-CMLogEntry -Value "$($Product): Driver CAB destination directory: $DriverExtractDest" -Severity 1
				if ($ComputerManufacturer -eq "Dell") {
					global:Write-CMLogEntry -Value "$($Product): Extracting $ComputerManufacturer drivers to $DriverExtractDest" -Severity 1
					Expand "$DriverSourceCab" -F:* "$DriverExtractDest"
				}
				if ($ComputerManufacturer -eq "Hewlett-Packard") {
					global:Write-CMLogEntry -Value "$($Product): Extracting $ComputerManufacturer drivers to $HPTemp" -Severity 1
					# Driver Silent Extract Switches
					$HPSilentSwitches = "-PDF -F" + "$DriverExtractDest" + " -S -E"
					global:Write-CMLogEntry -Value "$($Product): Using $ComputerManufacturer silent switches: $HPSilentSwitches" -Severity 1
					Start-Process -FilePath "$($TempDirectory + '\Driver Cab\' + $DriverCab)" -ArgumentList $HPSilentSwitches -Verb RunAs
					$DriverProcess = ($DriverCab).Substring(0, $DriverCab.length - 4)
					
					# Wait for HP SoftPaq Process To Finish
					While ((Get-Process).name -contains $DriverProcess) {
						global:Write-CMLogEntry -Value "$($Product): Waiting for extract process (Process: $DriverProcess) to complete..  Next check in 30 seconds" -Severity 1
						sleep -Seconds 30
					}
				}
				if ($ComputerManufacturer -eq "Lenovo") {
					# Driver Silent Extract Switches
					$global:LenovoSilentSwitches = "/VERYSILENT /DIR=" + '"' + $DriverExtractDest + '"' + ' /Extract="Yes"'
					global:Write-CMLogEntry -Value "$($Product): Using $ComputerManufacturer silent switches: $global:LenovoSilentSwitches" -Severity 1
					global:Write-CMLogEntry -Value "$($Product): Extracting $ComputerManufacturer drivers to $DriverExtractDest" -Severity 1
					Unblock-File -Path $($TempDirectory + '\Driver Cab\' + $DriverCab)
					Start-Process -FilePath "$($TempDirectory + '\Driver Cab\' + $DriverCab)" -ArgumentList $global:LenovoSilentSwitches -Verb RunAs
					$DriverProcess = ($DriverCab).Substring(0, $DriverCab.length - 4)
					# Wait for Lenovo Driver Process To Finish
					While ((Get-Process).name -contains $DriverProcess) {
						global:Write-CMLogEntry -Value "$($Product): Waiting for extract process (Process: $DriverProcess) to complete..  Next check in 30 seconds" -Severity 1
						sleep -seconds 30
					}
				}
			}
			else {
				global:Write-CMLogEntry -Value "Skipping. Drivers already extracted." -Severity 1
			}
		}
		else {
			global:Write-CMLogEntry -Value "$($Product): $DriverCab file download failed" -Severity 3
		}
	}

    elseif ($DriverDownload -eq "badLink") {
		global:Write-CMLogEntry -Value "$($Product): Operating system driver package download path not found.. Skipping $ComputerModel" -Severity 3
	}
	else {
        if ($drvlist -eq $null)
        {
		    global:Write-CMLogEntry -Value "$($Product): Driver package not found for $ComputerModel running Windows $WindowsVersion $Architecture. Skipping $ComputerModel" -Severity 2
        }
	}
	
	
	
    if  (($ComputerManufacturer = 'HP') -and ($global:Drvlist -ne $null))
    {
        if ($drvlist -ne $null)
        {
            foreach ($item in $global:Drvlist)
            {    
                $source = $item.Split(";")[1]
                $dest = $TempDirectory + "\" + $item.Split(";")[2] + ".exe"
                global:Write-CMLogEntry -Value "Download Driver from $source" -Severity 1
                Invoke-WebRequest -Uri $source  -OutFile $dest

                $splist = Get-ChildItem -Path C:\Windows\Temp\Drivers -Filter *.exe 

                foreach ($item in $splist)
                {
                    $arg = "/E /S /F c:\windows\temp\drivers\sp\" + ($item.Name).Split(".")[0]
                    Start-Process -FilePath $item.fullname -ArgumentList $arg -Wait -PassThru
                }
            }    
        }  
    }
    
	if ($ValidationErrors -eq 0) {

        global:Write-CMLogEntry -Value "======== $PRODUCT - $ComputerManufacturer $ComputerModel DRIVER PROCESSING FINISHED ========" -Severity 1	    
	
	}
}

function Update-Drivers {
	$DriverPackagePath = Join-Path $TempDirectory "Driver Files"
	Write-CMLogEntry -Value "Driver package location is $DriverPackagePath" -Severity 1
	Write-CMLogEntry -Value "Starting driver installation process" -Severity 1
	Write-CMLogEntry -Value "Reading drivers from $DriverPackagePath" -Severity 1
	# Apply driver maintenance package
	try {
        if ($ComputerManufacturer -eq "Lenovo") {

            Write-CMLogEntry -Value "Install Nuget Package Provider." -Severity 1
            Install-PackageProvider -Name NuGet -Force
            Write-CMLogEntry -Value "Install LSUClient Module" -Severity 1
            Install-Module -Name LSUClient -Force
			Import-Module -Name LSUClient
            Write-CMLogEntry -Value "Install Updates." -Severity 1
            $LenovoDRV = Get-LSUpdate -all | Where-Object {-not $_.IsInstalled -and $_.Installer.Unattended }

            if ($LenovoDRV.Length -ne 0)
            {
                foreach ($item in $LenovoDRV)
                {   
                    $package = $item.title                 
                    Write-CMLogEntry -Value "Install Update $package" -Severity 1
                    Write-Host $package
			        $item | Where-Object {-not $_.IsInstalled -and $_.Installer.Unattended } | Install-LSUpdate -Verbose
                }                                      
            }
        }

        if (($ComputerManufacturer.ToUpper() -eq "HP") -or ($ComputerManufacturer.ToUpper() -eq "HEWLETT-PACKARD"))
        {
            if ($global:Drvlist -ne $null)
            {
                Write-CMLogEntry -Value "Start Install HP Updates" -Severity 1
            
                    
                foreach ($item in $global:Drvlist)
                {   
                    $arg = $null   
                    $updatename = $item.Split(";")[0]      
                    $source = $TempDirectory + "\SP\" + $item.Split(";")[2]
                    $prog = $item.Split(";")[3] 
                    $setup = $prog.Split("""")[1]
                    $arg = $prog.Split("""")[2]

                    IF ((Test-Path $source) -and ($item.Split(";")[2] -notlike "*99099*") -and ($item.Split(";")[2] -notlike "*sp101371*") -and ($item.Split(";")[2] -notlike "*sp85511*"))
                    {   
                        Write-CMLogEntry -Value " Install $updatename" -Severity 1
    
                        Set-Location $source
                        
                        if ($arg.Length -ne 0 )
                        {
                            Start-Process $setup -ArgumentList $arg -Wait -PassThru
                        }
                        Else
                        {
                            # Start-Process $setup -Wait -PassThru
                        }
                    }
                }   
            }
        }
    }    
	catch [System.Exception] {
		Write-CMLogEntry -Value "An error occurred while attempting to apply the driver maintenance package. Error message: $($_.Exception.Message)" -Severity 3
        Stop-Transcript
        exit 1004
	}
	Write-CMLogEntry -Value "Finished driver maintenance." -Severity 1
    Stop-Transcript
    exit 0
}

if (($OSName -eq "Windows 10") -or ($OSName -eq "Windows 11"))
{
	# Download manufacturer lists for driver matching
	$Drivers = DownloadDriverList
	# Initiate matched downloads
	InitiateDownloads
	# Update driver repository and install drivers
	Update-Drivers
}
else {
	Write-CMLogEntry -Value "An upsupported OS was detected. This script only supports Windows 10 or Windows 11." -Severity 3; exit 1
}