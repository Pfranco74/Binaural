cls
Remove-Variable * -ErrorAction SilentlyContinue
$AllApp = $null
$count = $null
$datePattern = 'date="(.*?)"'
$timePattern = 'time="(.*?)"'

function AppstobeInstall ($logFilePathIME)
{
    $AppInst = $null
    $IME = 'In EspPhase: DeviceSetup. App'
    $logLinesIME = Get-Content -Path $logFilePathIME | Select-String -Pattern $IME
    
    # --[ Define a regular expression pattern to extract the log content and other information ]
    $logPattern  = '\[LOG\[(.*?)\]LOG\]'

    # --[ Outputting extracted information ]
    foreach ($line in $logLinesIME)
    {
        $log = [regex]::Match($line, $logPattern).Groups[1].Value
        $positionname = $log.IndexOf("App name: ")
        $positionid = $log.IndexOf("App ")
        $appname = ($log.Substring($positionname+1)).Replace("pp name: ","")
        $appid = (($log.Substring($positionid+1)).split(" "))[1]
        
        #$AppInst = "AppID: " + $appid + " has AppName: " + $AppNAme + "`r`n" 
        $AppInst = $appid + ";" + $AppNAme
        #write-host $AppInst -ForegroundColor Green
        $AllApp = $AllApp + @($AppInst)     
    }    
    Return $AllApp
}

function LogAppName ($AppControl)
{
    foreach ($item in $AllApp)
    {        
        if ($item -like "*$AppControl*")
        {         
            Return $item.Split(";")[1]
        }
    }
    Return $null   
}

function HowLong ($start,$end)
{
    if (($start -ne $null) -and ($end -ne $null))
    {
        $TakeThat = (New-TimeSpan -start $start -End $end).ToString()
        $TakeThat = "Total Time: " + $TakeThat
        Return $TakeThat
    }
}

if ((Test-Path "C:\data\Intune\logs") -eq $true)
{
    $JoinedFile = "C:\data\Intune\logs\AllIntuneManagementExtension.log"
    Get-Content -Path C:\data\Intune\logs\Intune*.log | Set-Content $JoinedFile    
}
else
{
    $JoinedFile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AllIntuneManagementExtension.log"
    Get-Content -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Intune*.log | Set-Content $JoinedFile       
}



    $readfile = Get-Content -Path $JoinedFile
    $AllApp = AppstobeInstall $JoinedFile 
    #write-host $Allapp -ForegroundColor Green             



    $AppDownloadStatus= $null
    $AppDownload = "Downloading app"
    $AppDownloadPER = "via DO, bytes "
    $AppHash = 'Starts verifying encrypted hash'
    $AppHashStatus = $null
    $AppUnzippingStatus= $null
    $AppUnzipping = "Start unzipping"
    $AppLaunchStatus= $null
    $AppLaunch = "Launch Win32AppInstaller in machine session"
    $timestart = $null
    $timeend = $null

    $beginapp = "<![LOG[[Win32App][V3Processor] Processing subgraph with app ids: "
    $completeapp1 = "<![LOG[[Win32App][DetectionActionHandler] Detection for policy with id"
    $completeapp2 = "resulted in action status: Success and detection state: Detected.]LOG]!>"
    $endapp = "<![LOG[[Win32App][EspManager] Updating ESP tracked install status from InProgress to Completed"
    $installOK = "<![LOG[[Win32App][ReportingManager] Desired state for app with id:"
    $installOKEnd = "Present""}}]LOG]!>"


    foreach ($item in $readfile)
    {   

    if ($item.StartsWith($beginapp) -eq $true)
    {
        $ids =  $item.Replace($beginapp,"")
        $ids = $ids.Split("]")[0]
        
        if ($ids.Length -ne 36)
        {
            $idarr = ($ids.Replace(" ","")).split(",")
            $begappid = $idarr[0]
            $SingleApp = $false
        }
        else
        {
            $begappid = $ids
            $SingleApp = $true
        }

        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timelogstart = ($time.Split("."))[0]            
        $datelogstart = $date
        
        $positionid = $Item.IndexOf("app ids: ")    
        #write-host $positionid        
        #$begappid = (((($item.Substring($positionid+9)).split("]"))[0]).split(""))[0] 
        #write-host $begappid -ForegroundColor Yellow
        if ($begappid.Contains(",") -eq $true)
        {
            #$begappid = $begappid.Substring(0,36)            
        }

      
        
    }

    if ($item.StartsWith($endapp) -eq $true)
    {
        #WRITE-HOST $item -ForegroundColor Green
        $endappOK = $true
        
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timelogend = ($time.Split("."))[0]            
        $datelogend = $date        

    }

    if ($item.StartsWith($installOK) -eq $true)
    {
        $xxx=$item
        if (($item.Contains($begappid) -eq $true) -and ($item.Contains($installOKEnd) -eq $true))
        {
            $endappOK = $true
        }
       
        
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timelogend = ($time.Split("."))[0]            
        $datelogend = $date        

    }

    if (($item.StartsWith($completeapp1) -eq $true) -and $item.Contains($completeapp2) -eq $true)
    {
        

    }


    if (($item -like "*$AppDownload*") -and $AppDownloadStatus -eq $null)
    {    
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timelog = ($time.Split("."))[0]            
        $datelog = $date 
            
        $positionid = $item.IndexOf("App:")            
        $appid = (((($item.Substring($positionid+1)).split("]"))[0]).split(""))[1] 
                
        $AppDownloadId = $appid
        
        $AppDownloadStatus = "Begin"
        $timestart = $timelog      
               
    }

    if ($item -like "*Notified DO Service the job is complete*")
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppDownloadStatus = $null                        
    }  


    if (($item -like "*$AppHash*") -and $AppHashStatus -eq $null)
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppHashStatus = "Begin"                   
    }

    if ($item -like "*download and decryption is successfully done*")
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppHashStatus = $null                     
    }  

    if (($item -like "*$AppUnzipping*") -and $AppUnzippingStatus -eq $null)
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppUnzippingStatus = "Begin"                   
    }

    if ($item -like "*Cleaning up staging content*")
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppUnzippingStatus = $null                     
    }  

    if (($item -like "*$AppLaunch*") -and $AppLaunchStatus -eq $null)
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppLaunchStatus = "Begin"                   
    }

        #if (($item -like "*Completed detectionManager SideCarFileDetectionManager, applicationDetectedByCurrentRule: True*") -or ($item -like "*Completed detectionManager SideCarRegistryDetectionManager, applicationDetectedByCurrentRule: True*"))
        #if (($endappOK -eq $true) -or ($item -like "*Completed detectionManager SideCarFileDetectionManager, applicationDetectedByCurrentRule: True*") -or ($item -like "*Completed detectionManager SideCarRegistryDetectionManager, applicationDetectedByCurrentRule: True*"))
        if (($endappOK -eq $true) -and ($SingleApp -eq $true))
        {
            #$date = [regex]::Match($item, $datePattern).Groups[1].Value
            #$time = [regex]::Match($item, $timePattern).Groups[1].Value
            #$timelog = ($time.Split("."))[0]            
            #$datelog = $date 

            $endappOK = $false
            $AppLaunchStatus = $null  

            #$timeend = $timelog  
            #$takethat = HowLong $timestart $timeend
            $takethat = HowLong $timelogstart $timelogend            
            
            $App = LogAppName $begappid
            $AppCtrl = $App
            if (($App -ne $null) -and ($takethat -notlike "*-*") -and ($PreviousApp -notlike $App)  -and ($takethat -notlike "*00:00:0*"))
            {
                Write-Host $App -ForegroundColor Green  
                Write-Host $takethat    
                $count = $count + 1
                $PreviousApp = $App        
            }                   
        }
        Else
        {
            for ($i = 0; $i -lt $idarr.Count; $i++)
            { 
                if (($item.Contains("[StatusService] Downloading app (id = ") -eq $true) -and ($item.Contains("0/0") -eq $true) -and ($item.Contains($idarr[$i]) -eq $true))
                {
                    $date = [regex]::Match($item, $datePattern).Groups[1].Value
                    $time = [regex]::Match($item, $timePattern).Groups[1].Value

                    $Mulitimelogstart = ($time.Split("."))[0]            
                    $Mulidatelogstart = $date
                    
                }

                if (($item.Contains("[Win32App][DetectionActionHandler] Detection for policy with id:") -eq $true) -and ($item.Contains("Success and detection state: Detected") -eq $true) -and ($item.Contains($idarr[$i]) -eq $true))
                {

                    $date = [regex]::Match($item, $datePattern).Groups[1].Value
                    $time = [regex]::Match($item, $timePattern).Groups[1].Value

                    $Mulitimelogend = ($time.Split("."))[0]            
                    $Mulidatelogend = $date                            

                    $MultiAppEnd = $true
                    $MultiAppID = $idarr[$i]
                }

                if ($MultiAppEnd -eq $true)
                {
                    #write-host $MultiAppEnd
                    $takethat = HowLong $Mulitimelogstart $Mulitimelogend            
            
                    $App = LogAppName $MultiAppID
                    $AppCtrl = $App
                    if (($App -ne $null) -and ($takethat -notlike "*-*") -and ($PreviousApp -notlike $App)  -and ($takethat -notlike "*00:00:0*"))
                    {
                        Write-Host $App -ForegroundColor Green  
                        Write-Host $takethat    
                        $count = $count + 1
                        $PreviousApp = $App        
                    }                   
                    $MultiAppEnd = $false
                }

            }   
        }

    if (($item -like "*$AppDownloadPER*"))
    {
        $line = $item.Split(" ")

        foreach ($item in $line)
        {
            if ($item -like "*/*")
            {
                $atual = $item.Split("/")[0]
                $total = $item.Split("/")[-1]
                if ($atual -ne 0)
                {
                    $downloadper = ($atual/$total).ToString("P")                    
                }
            }
        }       
    }
}

$App = LogAppName $AppDownloadId

if ($AppDownloadStatus -eq "Begin")
{   
    Write-host ""
    Write-Host $AppDownload -ForegroundColor Yellow
    Write-Host $logdate            
    write-host $App   
    Write-Host $downloadper
}

if ($AppHashStatus -EQ "Begin")
{
    Write-host ""
    Write-Host $AppHash -ForegroundColor Yellow
    Write-Host $logdate
    write-host $App   
}

if ($AppUnzippingStatus -EQ "Begin")
{
    Write-host ""
    Write-Host $AppUnzipping -ForegroundColor Yellow
    Write-Host $logdate
    write-host $App   
}

if ($AppLaunchStatus -eq "Begin")
{
    Write-host ""
    Write-Host $AppLaunch -ForegroundColor Yellow
    Write-Host $logdate
    write-host $App   
}

$howmanyapps = ($AllApp.Count) -1
if ($howmanyapps -EQ "-1")
{
    write-host ""
    Write-Host "No apps found to be install" -ForegroundColor Red
}
Else
{
    write-host ""
    Write-Host "Aplication $count of $howmanyapps installed" -ForegroundColor Yellow
}