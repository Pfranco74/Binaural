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
	$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $FileName
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

function CreateDir
{
    #Create a tag file just so Intune knows this was installed
    if (-not (Test-Path $LogDirectory))
    {
      Mkdir $LogDirectory
    }

    if (-not (Test-Path $TempDirectory))
    {
      Mkdir $TempDirectory
    }

    if (-not (Test-Path $Repo))
    {
        Mkdir $Repo
    }

    if (-not (Test-Path $WebRepo))
    {
        Mkdir $WebRepo
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

    
    if ((Test-Path $LogErr))
    {
        Remove-Item -Path $LogErr -Force
    }

    Rename-Item -Path $LogFile -NewName $LogErr
    
    if ((Test-Path $LogFile))
    {
        Remove-Item -Path $LogFile -Force
    }

    exit 13    
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
        if (($Package.category -notlike "*Firmware*") -and ($Package.category -notlike "*BIOS"))
        {
            $Filename = ($Package.location).Split("/")[-1]
            $SaveFile = Join-Path $WebRepo -ChildPath $Filename
            
            $msg = "Save Driver XML file" + $SaveFile
            Write-CMLogEntry -Value $msg

            Invoke-WebRequest -Uri $Package.location -OutFile $SaveFile        
        }
    }
    
    Return [xml]$PARSEDModelXML
}

function DownloadDriver
{     
    $createdir = Join-Path -Path $WebRepo -ChildPath $xmlfile.Package.id
    $check = $null

    if ((Test-Path $createdir))
    {
        $check = $True
    }

    if ($check -eq $True)
    {
            
        # Save driver to local repo
        $msg = "Save driver to local repo" 
        Write-CMLogEntry -Value $msg      
        foreach ($file in $xmlfile.Package.Files.SelectNodes('descendant-or-self::File'))
        {
            $id = $xmlfile.Package.id
            $destinationfilemane = $file.Name
    
            $FindSource = $PARSEDModelXML.packages.package.location
            $baselocation =  "https://"
            foreach ($Find in $FindSource)
            {
                if ($find -like "*$id*")
                {
                    $FindSplit = $Find.Split("/")
                    $count = ($FindSplit.Count - 2)
                    for ($i = 0; $i -le ($FindSplit.Count -2); $i++)
                    {            
                        if ($i -ge 2)
                        {
                            $baselocation = $baselocation + $FindSplit[$i] + '/'                  
                        }            
                    }       
                }    
            }                           
        
            $sourcefilename = $BaseLocation + $file.name           
            $savefilename = Join-Path $createdir -ChildPath $destinationfilemane

            $FindSource = $PARSEDModelXML.packages.package.location

            if (-not (Test-Path $savefilename))
            {               
                $msg = "Download " + $sourcefilename 
                Write-CMLogEntry -Value $msg

                Invoke-WebRequest -Uri $sourcefilename -OutFile $savefilename                                                             
            }            
            #else
            #{
                #$wc = [System.Net.WebClient]::new()
                
                #$webhash = Get-FileHash -InputStream ($wc.OpenRead($sourcefilename))
                #$localhash = Get-FileHash -path $savefilename

                #if ($webhash.hash -ne $localhash.hash)
                #{
                    #Write-Host "Hash is diferent force download $sourcefilename "
                    #Invoke-WebRequest -Uri $sourcefilename -OutFile $savefilename                                                                                
                #}
            #}                              
        }                                               
    }
}

function Extract
{
    $msg = "Start extracting driver" 
    Write-CMLogEntry -Value $msg      

    $commandlocation = Join-Path -Path $WebRepo -ChildPath $xmlfile.Package.id

    if (-not (Test-Path $commandlocation))
    {
        $msg = "Nothing to do " + $commandlocation 
        Write-CMLogEntry -Value $msg      

        return
    }
        
        
    $ExtractCommand = (($xmlfile.Package.ExtractCommand).Split(''))
    $extractfolder = $commandlocation + "\Extract"

    $msg = "Start extracting to " + $extractfolder
    Write-CMLogEntry -Value $msg      


    if (-not (Test-Path $extractfolder))
    {
        mkdir $extractfolder
    }
        
    $argextract = "/VERYSILENT /DIR=" + $extractfolder + " /EXTRACT=""" + "YES" + """"
    $arg = $null
    for ($i = 0; $i -le $ExtractCommand.Count; $i++)
    { 
        if ($i -eq  0)
        {
            $runcommand = $ExtractCommand[$i]
        }
        else
        {    
        if (($ExtractCommand[$i] -notlike '*%*') -and ($ExtractCommand[$i] -notlike '*EXTRACT*'))
        {
            $argsarray = $ExtractCommand[$i]
            $arg = $arg + $argsarray            
        }      
        }    
    }       

    # Extract driver

    if ((Get-ChildItem -Path $extractfolder -Force | Measure-Object).count -eq 0)
    {
        Set-Location $commandlocation
        $run = ( Start-Process -Wait -FilePath $runcommand -ArgumentList $argextract -PassThru )

        $msg = "Extracting end"
        Write-CMLogEntry -Value $msg      

    }
}

function InstallDriver ($id)
{          
        $commandlocation = Join-Path -Path $WebRepo -ChildPath $id
        $extractfolder = $commandlocation + "\Extract"

        if (-not (Test-Path $commandlocation))
        {
            $msg = "Driver not applicable"
            Write-CMLogEntry -Value $msg      

            return
        }
        $msg = "Install driver" + $id
        Write-CMLogEntry -Value $msg      

        $dpinst = $null
        $fileexe = $null
        $filemsi = $null
        $filebat = $null
        
        $dpinst = $extractfolder + "\dpinst.exe"
        $fileexe = (Get-ChildItem -Path $extractfolder -Filter *.exe).name
        $filemsi = (Get-ChildItem -Path $extractfolder -Filter *.msi).name
        $filebat = (Get-ChildItem -Path $extractfolder -Filter *.bat).name

        Set-Location $extractfolder    
    

        # Instal Driver DPInst
        if ((Test-Path $dpinst))
        {
            $commanddp = "dpinst.exe"
            $argsdp = "/s /se"
            $rundp = ( Start-Process -Wait -FilePath $commanddp -ArgumentList $argsdp -PassThru )
            Return
        }

        if (($fileexe -ne $null))
        {
            foreach ($exefile in $fileexe)
            {  
                $commandexe = $exefile

                if ($commandexe.ToUpper() -eq 'DRIVERSETUP.EXE')
                {
                    $argsexe = "/silent /norestart"
                }
                else
                {
                    $argsexe = "-s -norestart"
                }
                $runexe = ( Start-Process -Wait -FilePath $commandexe -ArgumentList $argsexe -PassThru ) 
                    
                if ($runexe.ExitCode -eq 1)
                {                            
                    $commandexe = $exefile
                    $argsexe = "-s -overwrite"
                    $runexe = ( Start-Process -Wait -FilePath $commandexe -ArgumentList $argsexe -PassThru )                            
                }               
            }
            Return
        }
    
        if ($filebat -ne $null)
        {       
            foreach ($batfile in $filebat)
            {  
                ((Get-Content $batfile).ToUpper()).Replace("PAUSE","") | Out-File $batfile -Force utf8    
                $commandbat = $batfile
                $runbat = ( Start-Process -Wait -FilePath $commandbat -PassThru )                                
            }
            Return
        }   
        
        if ($filemsi -ne $null)
        {               
            $commandmsi = $filemsi
            $argsmsi = "/qn /norestart"
            $runmsi = ( Start-Process -Wait -FilePath $commandmsi -ArgumentList $argsmsi -PassThru )                 
            Return
        }                  
}

function DetectDriver ($xmlfile)
{    
        [xml]$xmlfile = Get-Content -Path $file.FullName        
        $collection = $xmlfile.Package.DetectVersion._PnPID

        $msg = "Start if driver is needed"
        Write-CMLogEntry -Value $msg      

        foreach ($item in $collection)
        {
            $ID = $null
            $ID = (($item.'#cdata-section').Split("&"))[0]
            $ID = "*" + $ID + "*"

            # Get driver version
            [STRING]$version = $xmlfile.Package.version

            
            #write-host $ID -ForegroundColor Red
            foreach ($drv in $Driver)
            {     
                $forceupdate = $null
                $LocalDriverVersionTemp = $null      
                if ($drv.hardwareid -like $ID)
                {  
                    $LocalVersion = [string]$drv.DriverVersion
                    $WebVersion = [string]$version    
                    if ($LocalVersion -lt $WebVersion)
                    {   
                        $msg = "The driver is to be updated" + $createdir
                        Write-CMLogEntry -Value $msg      
                          
                        $createdir = Join-Path -Path $WebRepo -ChildPath $xmlfile.Package.id
                         
                        if (-not (Test-Path $createdir))
                        {
                            Mkdir $createdir
                        }
                        $forcerun = $createdir + "\Force.Download"

                        Out-File -FilePath $forcerun -InputObject "Force Download" -Force -Encoding utf8                        
                        return
                    }
                }
                if ((($ID.Contains("-") -eq "True")) -and ($ID.Contains("{") -eq "True"))
                {
                    $msg = "The driver is to be updated" + $createdir
                    Write-CMLogEntry -Value $msg      
                          
                    $createdir = Join-Path -Path $WebRepo -ChildPath $xmlfile.Package.id
                         
                    if (-not (Test-Path $createdir))
                    {
                        Mkdir $createdir
                    }
                    $forcerun = $createdir + "\Force.Download"

                    Out-File -FilePath $forcerun -InputObject "Force Download" -Force -Encoding utf8                        
                    return
                }                                            

            }
        }   
}

cls

#Create Temp Directories
$TempDirectory = "C:\Windows\Temp\Drivers\Lenovo"
$LogDirectory = "C:\Windows\Temp\Logs\Drivers"
$LogFile = "C:\Windows\Temp\Logs\Drivers\Lenovo_Drivers_Update.log"
$LogErr = "C:\Windows\Temp\Logs\Drivers\Lenovo_Drivers_Update.nok"
$Repo = "C:\Windows\Temp\Drivers\Lenovo\Repo"
$WebRepo = "C:\Windows\Temp\Drivers\Lenovo\WebRepo"
CreateDir
# Start logging
Start-Transcript $LogFile
Write-Host "Start Drivers Update Process"

$msg = "Start Drivers Update Process"
Write-CMLogEntry -Value $msg

try
{
    $Manufacturer = Manufacturer

    if ($Manufacturer -ne 'LENOVO')
    {
        Write-Output "Skip Update not Lenovo Model"
        Stop-Transcript
        exit 0
    }
}
catch
{
    $msg = "Error getting manufacturer"
    Write-CMLogEntry -Value $msg

    ForceErr  
}

#Get Computer Model
$model = ComputerModel
Write-Host "Lenovo Model is: $Model"

#Get Os Version
$OSversion = OSVersion
Write-Host "Operation System Version is: $OSversion"

#Copy Files
Write-Host "Start to copy Repo"
CopyFiles

# Get Install Drivers
Write-Host "Get installed Drivers"
$msg = "Get installed Drivers"
Write-CMLogEntry -Value $msg      

$Driver = Get-WmiObject Win32_PnPSignedDriver | select Devicename, HardwareID, DriverVersion

# Process local XML Driver Model
Write-Host "Process local XML Driver Model"
$msg = "Process local XML Driver Model"
Write-CMLogEntry -Value $msg      

[xml]$PARSEDModelXML = LocalXml

# Get all drivers information
Write-Host "Get all web drivers information"
$msg = "Get all web drivers information"
Write-CMLogEntry -Value $msg      

$XmlList = Get-ChildItem -Path $WebRepo -Filter *.xml

# Process data in XML driver
Write-Host "Process data in XML driver"
$msg = "Process data in XML driver"
Write-CMLogEntry -Value $msg      

foreach ($file in $XmlList)
{
    $collection = $null
    [xml]$xmlfile = Get-Content -Path $file.FullName    
    $collection = $xmlfile.Package.DetectVersion._PnPID

    foreach ($item in $collection)
    {
        Set-Location -Path $WebRepo


        # Detect if driver is aplly
        $msg = "Detect Driver " + $xmlfile.Package.name
        Write-Host $msg
        Write-CMLogEntry -Value $msg      

        DetectDriver $xmlfile

        # Dowload Driver
        $msg = "Start Download Driver Process"
        Write-Host $msg
        Write-CMLogEntry -Value $msg      

        DownloadDriver

        #Extract Driver
        $msg = "Start Extract Driver Process"
        Write-Host $msg
        Write-CMLogEntry -Value $msg      

        Extract    
    }
      
}  

# Install Driver
write-host "Start Install Driver Process"
$msg = "Start Install Driver Process"
Write-CMLogEntry -Value $msg      


$downloaddrivers = Get-ChildItem -Path $WebRepo -Filter *.
foreach ($downdriver in $downloaddrivers)
{              
    $msg = "Install Driver " + $downdriver.Name
    Write-CMLogEntry -Value $msg    

    InstallDriver $downdriver.Name    
}

Stop-Transcript