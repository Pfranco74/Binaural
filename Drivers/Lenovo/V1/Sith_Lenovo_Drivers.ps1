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
	#$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $FileName
    $LogFilePath = $LogFile
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
            try
            {
                Invoke-WebRequest -Uri $Package.location -OutFile $SaveFile        
            }
            catch [System.Net.WebException],[System.Exception]
            {
                Write-Host "Cannot Access to WEB"
                ForceErr
            }
            

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
        $installcommand = $commandlocation + "\install.txt"
        $command = $null
        $Arguments = $null
        $dpinst = $null
        $skipinstall = @("N35A608W")

        if (-not (Test-Path $installcommand))
        {
            $msg = "Driver not applicable " + $id
            Write-CMLogEntry -Value $msg      

            return
        }

        foreach ($itemdrv in $skipinstall)
        {
            if ($itemdrv -eq $id.ToUpper())
            {
                $msg = "Driver not applicable " + $id
                Write-CMLogEntry -Value $msg      

                return
            }
        }
   
        $msg = "Install driver " + $id
        Write-CMLogEntry -Value $msg 
        
        Set-Location $commandlocation

        $extractfolder = $commandlocation + "\Extract"

        if (-not (Test-Path $extractfolder))
        {
            mkdir $extractfolder
        }

        $readinstallcommand = Get-Content -Path $installcommand     
        $readinstallcommandarr = $readinstallcommand.Split(" ")

        $command = $readinstallcommandarr[0]

        for ($i = 1; $i -lt $readinstallcommandarr.Count; $i++)
        { 
            if ((($readinstallcommandarr[$i].ToUpper()) -EQ "/DIR=%PACKAGEPATH%"))
            {
                $Arguments = $Arguments + $readinstallcommandarr[$i].Replace("%PACKAGEPATH%",$extractfolder) + " "
            }
            Else
            {
            
                $Arguments = $Arguments + $readinstallcommandarr[$i] + " "
            }
            
        }
        $run = ( Start-Process -Wait -FilePath $command -ArgumentList $Arguments -PassThru )     
        
                
       
        $dpinst = $null
        $fileexe = $null
        $filemsi = $null
        $filebat = $null
        $filecmd = $null
                
        $dpinst = $extractfolder + "\dpinst.exe"
        $fileexe = (Get-ChildItem -Path $extractfolder -Filter *.exe).name
        $filemsi = (Get-ChildItem -Path $extractfolder -Filter *.msi).name
        $filebat = (Get-ChildItem -Path $extractfolder -Filter *.bat).name
        $filecmd = (Get-ChildItem -Path $extractfolder -Filter *.cmd).name


        Set-Location $extractfolder    
    

        # Instal Driver DPInst
        if ((Test-Path $dpinst))
        {
            $commanddp = "dpinst.exe"
            $argsdp = "/s /se"
            $rundp = ( Start-Process -Wait -FilePath $commanddp -ArgumentList $argsdp -PassThru )
            Return
        }

        if (($fileexe -ne $null) -and ($filebat -eq $null))
        {
            foreach ($exefile in $fileexe)
            {  
                $commandexe = $exefile

                $argsexe = "-s -norestart"

                if ($commandexe.ToUpper() -eq 'DRIVERSETUP.EXE')
                {
                    $argsexe = "/silent /norestart"
                }

                if ($commandexe.ToUpper() -eq 'INSTALLER.EXE')
                {
                    $argsexe = "-s -o"
                    if (-not (Test-Path "c:\TEMP\INSTALLER"))
                    {
                        Mkdir "c:\TEMP\INSTALLER"
                    }

                    Copy-Item $extractfolder "c:\TEMP\INSTALLER" -Recurse -Force

                    $commandexe = "c:\TEMP\INSTALLER\EXTRACT\INSTALLER.EXE"

                }
          
                $runexe = ( Start-Process -Wait -FilePath $commandexe -ArgumentList $argsexe -PassThru ) 
                    
                if ($runexe.ExitCode -eq 1)
                {                            
                    $commandexe = $exefile
                    $argsexe = "-s -o"
                    $runexe = ( Start-Process -Wait -FilePath $commandexe -ArgumentList $argsexe -PassThru )  
                }  

                if ((Test-Path "c:\TEMP\INSTALLER"))
                {
                    Rmdir "c:\TEMP\INSTALLER" -Recurse -Force
                }

             
            }

            Return
        }
    
        if ($filebat -ne $null)
        {       
            foreach ($batfile in $filebat)
            {  
                ((Get-Content $batfile).ToUpper()).Replace("PAUSE","") | Out-File $batfile -Force default
                ((Get-Content $batfile).ToUpper()).Replace("SHUTDOWN","REM SHUTDOWN") | Out-File $batfile -Force default
                $commandbat = $batfile
                $runbat = ( Start-Process -Wait -FilePath $commandbat -PassThru )  
            }
            Return
        }   

        if ($filecmd -ne $null)
        {       
            foreach ($cmdfile in $filecmd)
            {  
                $commandcmd = $cmdfile
                $runcmd = ( Start-Process -Wait -FilePath $commandcmd -PassThru )  
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

function DetectDriver ($xmlfile,$localdrv)
{    
        
    $LocalHardID = $localdrv
    
    $xmldrv = Get-Content -Path $file.FullName
    [xml]$PARSExmldrv = $xmldrv -replace "^$UTF8ByteOrderMark"
    $SingleDriver = $PARSExmldrv.Package.DetectInstall._Driver
    $AndDriver = $PARSExmldrv.Package.DetectInstall.And._Driver
    $OrDriver = $PARSExmldrv.Package.DetectInstall.or._Driver
    $detect = $PARSExmldrv.Package.DetectInstall
    if (($SingleDriver -ne $null) -and ($detect -ne $null))
    {
        $WebDrvVersion = (($PARSExmldrv.Package.DetectInstall._Driver).Version)
        if ($WebDrvVersion.Contains("^"))
        {
            $WebDrvVersion = $WebDrvVersion.Replace("^","")
        }
        $WebDrvId = (($PARSExmldrv.Package.DetectInstall._Driver).HardwareID).'#cdata-section'

        foreach ($WebDrv in $WebDrvId)
        {
            foreach ($LocalHard in $LocalHardID)
            {
                if ($LocalHard.hardwareid -ne $null)
                {
                    $searchhardwareid = $LocalHard.hardwareid
                    $searchhardwarever = $LocalHard.driverversion
                    $WebDrv4 = $WebDrv.Substring($WebDrv.Length - 4)
                    
                    if (($searchhardwareid.Contains($WebDrv)) -or ($searchhardwareid.Contains($WebDrv4)))
                    {
                        if ($searchhardwarever -ge $WebDrvVersion)
                        {

                        }
                        else
                        {   
                            
                            $createdir = Join-Path -Path $WebRepo -ChildPath $PARSExmldrv.Package.id

                            $msg = "The driver is to be updated" + $createdir
                            Write-CMLogEntry -Value $msg    
                         
                            if (-not (Test-Path $createdir))
                            {
                                Mkdir $createdir
                            }
                            $forcerun = $createdir + "\install.txt"
                            $command = $PARSExmldrv.Package.ExtractCommand
                            Out-File -FilePath $forcerun -InputObject $command -Force -Encoding default                             

                            Return
                        }
                    }           
                }       
            }    
        }  

        $SingleDriver = $null
    }

    if (($OrDriver -ne $null) -and ($detect -ne $null))
    {
        $howmanydrv = ($PARSExmldrv.Package.DetectInstall.Or._Driver).Version
        if ($howmanydrv.count -eq 1)
        {
            $WebDrvVersion = (($PARSExmldrv.Package.DetectInstall.Or._Driver).Version)       
            if ($WebDrvVersion.Contains("^"))
            {
                $WebDrvVersion = $WebDrvVersion.Replace("^","")
            }

            $WebDrvId = (($PARSExmldrv.Package.DetectInstall.Or._Driver).HardwareID).'#cdata-section'

            foreach ($WebDrv in $WebDrvId)
            {
                foreach ($LocalHard in $LocalHardID)
                {
                    if ($LocalHard.hardwareid -ne $null)
                    {
                        $searchhardwareid = $LocalHard.hardwareid
                        $searchhardwarever = $LocalHard.driverversion
                        $WebDrv4 = $WebDrv.Substring($WebDrv.Length - 4)
                    
                        if (($searchhardwareid.Contains($WebDrv)) -or ($searchhardwareid.Contains($WebDrv4)))

                        {
                            if ($searchhardwarever -ge $WebDrvVersion)
                            {

                            }
                            else
                            {
                                $createdir = Join-Path -Path $WebRepo -ChildPath $PARSExmldrv.Package.id
                                
                                $msg = "The driver is to be updated" + $createdir
                                Write-CMLogEntry -Value $msg    
                         
                                if (-not (Test-Path $createdir))
                                {
                                    Mkdir $createdir
                                }
                                $forcerun = $createdir + "\install.txt"
                                $command = $PARSExmldrv.Package.ExtractCommand
                                Out-File -FilePath $forcerun -InputObject $command -Force -Encoding default                          

                                Return
                            }
                        }           
                    }       
                }    
            }  

            $OrDriver = $null
        }
        Else
        {
            $MultiDrv = ($PARSExmldrv.Package.DetectInstall.Or._Driver)
            foreach ($itemdrv in $MultiDrv)
            {
                $WebDrvVersion = $itemdrv.Version                 
                if ($WebDrvVersion.Contains("^"))
                {
                    $WebDrvVersion = $WebDrvVersion.Replace("^","")
                }

                $WebDrvId = $itemdrv.HardwareID.'#cdata-section'              
                foreach ($WebDrv in $WebDrvId)
                {
                    foreach ($LocalHard in $LocalHardID)
                    {
                        if ($LocalHard.hardwareid -ne $null)
                        {
                            $searchhardwareid = $LocalHard.hardwareid
                            $searchhardwarever = $LocalHard.driverversion
                            $WebDrv4 = $WebDrv.Substring($WebDrv.Length - 4)
                    
                            if (($searchhardwareid.Contains($WebDrv)) -or ($searchhardwareid.Contains($WebDrv4)))
                            {
                                if ($searchhardwarever -ge $WebDrvVersion)
                                {

                                }
                                else
                                {
                                    $createdir = Join-Path -Path $WebRepo -ChildPath $PARSExmldrv.Package.id
                                    
                                    $msg = "The driver is to be updated" + $createdir
                                    Write-CMLogEntry -Value $msg    
                         
                                    if (-not (Test-Path $createdir))
                                    {
                                        Mkdir $createdir
                                    }
                                    $forcerun = $createdir + "\install.txt"
                                    $command = $PARSExmldrv.Package.ExtractCommand
                                    Out-File -FilePath $forcerun -InputObject $command -Force -Encoding default                              

                                    Return
                                }
                            }           
                        }       
                    }    
                }  
            }
            $OrDriver = $null
            
        }
    }


    if (($AndDriver -ne $null) -and ($detect -ne $null))
    {      
        $howmanydrv = ($PARSExmldrv.Package.DetectInstall.And._Driver).Version
        if ($howmanydrv.count -eq 1)
        {
            $WebDrvVersion = (($PARSExmldrv.Package.DetectInstall.And._Driver).Version)       
            if ($WebDrvVersion.Contains("^"))
            {
                $WebDrvVersion = $WebDrvVersion.Replace("^","")
            }

            $WebDrvId = (($PARSExmldrv.Package.DetectInstall.And._Driver).HardwareID).'#cdata-section'

            foreach ($WebDrv in $WebDrvId)
            {
                foreach ($LocalHard in $LocalHardID)
                {
                    if ($LocalHard.hardwareid -ne $null)
                    {
                        $searchhardwareid = $LocalHard.hardwareid
                        $searchhardwarever = $LocalHard.driverversion
                        $WebDrv4 = $WebDrv.Substring($WebDrv.Length - 4)
                    
                        if (($searchhardwareid.Contains($WebDrv)) -or ($searchhardwareid.Contains($WebDrv4)))
                        {
                            if ($searchhardwarever -ge $WebDrvVersion)
                            {

                            }
                            else
                            {
                                $createdir = Join-Path -Path $WebRepo -ChildPath $PARSExmldrv.Package.id
                                
                                $msg = "The driver is to be updated" + $createdir
                                Write-CMLogEntry -Value $msg    
                         
                                if (-not (Test-Path $createdir))
                                {
                                    Mkdir $createdir
                                }
                                $forcerun = $createdir + "\install.txr"
                                $command = $PARSExmldrv.Package.ExtractCommand
                                Out-File -FilePath $forcerun -InputObject $command -Force -Encoding default                              

                                Return
                            }
                        }           
                    }       
                }    
            }  

            $AndDriver = $null
        }
        Else
        {
            $MultiDrv = ($PARSExmldrv.Package.DetectInstall.And._Driver)
            foreach ($itemdrv in $MultiDrv)
            {
                $WebDrvVersion = $itemdrv.Version                  
                if ($WebDrvVersion.Contains("^"))
                {
                    $WebDrvVersion = $WebDrvVersion.Replace("^","")
                }

                $WebDrvId = $itemdrv.HardwareID.'#cdata-section'            
                foreach ($WebDrv in $WebDrvId)
                {
                    foreach ($LocalHard in $LocalHardID)
                    {
                        if ($LocalHard.hardwareid -ne $null)
                        {
                            $searchhardwareid = $LocalHard.hardwareid
                            $searchhardwarever = $LocalHard.driverversion
                            $WebDrv4 = $WebDrv.Substring($WebDrv.Length - 4)
                    
                            if (($searchhardwareid.Contains($WebDrv)) -or ($searchhardwareid.Contains($WebDrv4)))
                            {
                                if ($searchhardwarever -ge $WebDrvVersion)
                                {

                                }
                                else
                                {
                                    $createdir = Join-Path -Path $WebRepo -ChildPath $PARSExmldrv.Package.id
                                
                                    $msg = "The driver is to be updated" + $createdir
                                    Write-CMLogEntry -Value $msg    
                         
                                    if (-not (Test-Path $createdir))
                                    {
                                        Mkdir $createdir
                                    }
                                    $forcerun = $createdir + "\install.txt"
                                    $command = $PARSExmldrv.Package.ExtractCommand
                                    Out-File -FilePath $forcerun -InputObject $command -Force -Encoding default                              

                                    Return
                            }           
                        }       
                    }    
                }  
            }
            $AndDriver = $null
            
        }
    }
}
}

cls

#Create Temp Directories
$TempDirectory = "C:\Windows\Temp\Drivers\Lenovo"
$LogDirectory = "C:\Windows\Temp\Logs\Drivers"
$LogTrans = "C:\Windows\Temp\Logs\Drivers\Run_Sith_Lenovo_Drivers.log"
$LogFile = "C:\Windows\Temp\Logs\Drivers\Lenovo_Drivers_Update.log"
$LogErr = "C:\Windows\Temp\Logs\Drivers\Lenovo_Drivers_Update.nok"
$Repo = "C:\Windows\Temp\Drivers\Lenovo\Repo"
$WebRepo = "C:\Windows\Temp\Drivers\Lenovo\WebRepo"
CreateDir
# Start logging
Start-Transcript $LogTrans
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
$msg = "Lenovo Model is: $Model"
Write-Host $msg
Write-CMLogEntry -Value $msg


#Get Os Version
$OSversion = OSVersion
$msg = "Operation System Version is: $OSversion"
Write-Host $msg
Write-CMLogEntry -Value $msg



#Copy Files
Write-Host "Start to copy Repo"
CopyFiles

# Get Install Drivers
Write-Host "Get installed Drivers"
$msg = "Get installed Drivers"
Write-CMLogEntry -Value $msg      

$Driver = Get-WmiObject Win32_PnPSignedDriver | select Devicename, HardwareID, DriverVersion
#$LocalHardID = Get-WmiObject Win32_PnPSignedDriver | select hardwareid, driverversion

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

#$XmlList = Get-ChildItem -Path c:\Windows\Temp\Drivers\Lenovo\WebRepo\r0hd122w_2_.xml
# Process data in XML driver
Write-Host "Process data in XML driver"
$msg = "Process data in XML driver"
Write-CMLogEntry -Value $msg      

foreach ($file in $XmlList)
{
    $Msg = "Process File " +  $file.FullName    
    Write-Host $msg
    Write-CMLogEntry -Value $msg      

    $collection = $null
    [xml]$xmlfile = Get-Content -Path $file.FullName    
    $collection = $xmlfile.Package.DetectVersion._PnPID
    Set-Location -Path $WebRepo


    # Detect if driver is aplly
    $msg = "Detect Driver " + $xmlfile.Package.name
    Write-Host $msg
    Write-CMLogEntry -Value $msg      

    DetectDriver $xmlfile $Driver

    # Dowload Driver
    $msg = "Start Download Driver Process"
    Write-Host $msg
    Write-CMLogEntry -Value $msg      

    DownloadDriver

    #Extract Driver
    $msg = "Start Extract Driver Process"
    Write-Host $msg
    Write-CMLogEntry -Value $msg      

    #Extract    
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
    
    Write-host $msg  

    InstallDriver $downdriver.Name    
}

Stop-Transcript
