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
        $CHANGEDAY = New-TimeSpan $start $end
        if (($CHANGEDAY.Hours) -like "-*")
        {
            $HRS = ($CHANGEDAY.Hours) + 23
            $MIN = ($CHANGEDAY.Minutes) + 59
            $SEC = ($CHANGEDAY.Seconds) + 59
            $TakeThat = "Total Time: " + $HRS + ":" + $MIN  + ":" + $SEC
            Return $TakeThat
        }
        ELSE
        {
            $TakeThat = "Total Time: " + $TakeThat
            Return $TakeThat
        }
    }
}


if ((Test-Path "C:\data\Intune\logs") -eq $true)
{
    $JoinedFile = "C:\data\Intune\logs\AllIntuneManagementExtension.log"
    Get-Content -Path C:\data\Intune\logs\Intune*.log | Set-Content $JoinedFile    
}
else
{
    $JoinedFile = $env:USERPROFILE + "\AllIntuneManagementExtension.log"
    Get-Content -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Intune*.log | Set-Content $JoinedFile       
}



$readfile = Get-Content -Path $JoinedFile
$AllApp = AppstobeInstall $JoinedFile 
#write-host $Allapp -ForegroundColor Green     


$wtf = "WTF"
$wtfcheck = $null
$AppDownloadStatus = $null
$portalapp = $null
$beginapp = "<![LOG[[Win32App][V3Processor] Processing subgraph with app ids: "
$AppDownload = "<![LOG[[StatusService] Downloading app"               
$AppDownloadBytes = "bytes 0/0" 
$portalappbeg = "<![LOG[[Package Manager] BytesRequired - 0BytesDownloaded - 0DownloadProgress - 1InstallationProgress - 0"
$dateportalappend = "<![LOG[[WinGetLocalProgressAndResultSender] Changing app state to download complete"
$AppDownloadPER = "via DO, bytes "
$AppCheckHash = "<![LOG[[Win32App] Starts verifying encrypted hash]LOG"
$AppDecryp = "<![LOG[[Win32App DO] DO download and decryption is successfully done"
$AppUnzip = "<![LOG[[Win32App] Unzipping file on session"
$AppInst = "<![LOG[[Win32App] Launch Win32AppInstaller "
$completeapp1 = "<![LOG[[Win32App][DetectionActionHandler] Detection for policy with id"
$completeapp2 = "resulted in action status: Success and detection state: Detected.]LOG]!>"
$endapp = "<![LOG[[Win32App][EspManager] Updating ESP tracked install status from InProgress to Completed"
$installOK = "<![LOG[[Win32App][ReportingManager] Desired state for app with id:"
$installOKEnd = "Present""}}]LOG]!>"
$MultiAppIDSearch = "<![LOG[[Win32App][DownloadActionHandler] Handler invoked for policy with id: "

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

        if ($begappid.Contains(",") -eq $true)
        {
            #$begappid = $begappid.Substring(0,36)        
        }

        if ($StartAppsInst -eq $null)
        {
            $StartAppsInst = $timelogstart

        }
    }

    if (($item.StartsWith($AppDownloadStatus) -eq $true) -and ($item.Contains($AppDownloadBytes)) -eq $true )
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeAppdownloadstart = ($time.Split("."))[0]        
        $dateAppdownloadstart = $date
    }

    if (($item.StartsWith($portalappbeg) -eq $true) -and $portalapp -eq $null)
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeportalappbeg = ($time.Split("."))[0]   
        $dateportalappbeg = $date

        $portalapp = $true
    }
            
    if (($item.StartsWith($portalappend) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeportalappend = ($time.Split("."))[0]        
        $dateportalappend = $date   
    }

    if (($item.StartsWith($MultiAppIDSearch) -eq $true))
    {
        $singleID = ($item.Replace($MultiAppIDSearch,"")).split(" ")[0]
    }



    if (($item.StartsWith($AppCheckHash) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeAppCheckHashstart = ($time.Split("."))[0]        
        $dateAppCheckHashstart = $date
    }

    if (($item.StartsWith($AppDecryp) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeAppDecrypstart = ($time.Split("."))[0]        
        $dateAppDecrypstart = $date
    }

    if (($item.StartsWith($AppUnzip) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeAppUnzipstart = ($time.Split("."))[0]        
        $dateAppUnzipstart = $date
    }

    if (($item.StartsWith($AppInst) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeAppInststart = ($time.Split("."))[0]        
        $dateAppInstDecrypstart = $date
    }

    if ($item.StartsWith($endapp) -eq $true)
    {        
        $endappOK = $true
        
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timelogend = ($time.Split("."))[0]        
        $datelogend = $date        

    }

    if ($item.StartsWith($installOK) -eq $true)
    {        
        if (($item.Contains($begappid) -eq $true) -and ($item.Contains($installOKEnd) -eq $true))
        {
            $endappOK = $true
        }
       
        
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timelogend = ($time.Split("."))[0]            
        $datelogend = $date        

    }

    if (($item.StartsWith($AppDownload)) -and $AppDownloadStatus -eq $null)
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

    if (($endappOK -eq $true) -and ($SingleApp -eq $true))
    {

            $endappOK = $false
            $AppLaunchStatus = $null  

            $takethat = HowLong $timelogstart $timelogend 
            $takethatdownload = HowLong $timeAppdownloadstart $timeAppCheckHashstart
            $takethathash = HowLong $timeAppCheckHashstart $timeAppDecrypstart
            $takethatunzip = HowLong $timeAppUnzipstart $timeAppInststart
            $takethatinst = HowLong $timeAppInststart $timelogend

            if ($portalapp -eq $true)
            {
                $takethatinst = HowLong $timeportalappbeg $timeportalappend
            }
                       
            
            
            $App = LogAppName $begappid
            $AppCtrl = $App
            if (($App -ne $null) -and ($takethat -notlike "*-*") -and ($PreviousApp -notlike $App)  -and ($takethat -notlike "*00:00:0*"))
            {
                if ($portalapp -ne $true)
                {
                    Write-Host $App -ForegroundColor Green  
                    Write-Host "Download Time" $takethatdownload.Replace("Total Time: ","") 
                    Write-Host "Hash Time" $takethathash.Replace("Total Time: ","") 
                    Write-Host "Unzip Time" $takethatunzip.Replace("Total Time: ","") 
                    Write-Host "Install Time" $takethatinst.Replace("Total Time: ","") 
                    Write-Host $takethat
                    
                    Write-Host ""
                }
                else
                {
                    $portalapp = $null
                    Write-Host $App -ForegroundColor Green  
                    Write-Host "Install Time" $takethatinst.Replace("Total Time: ","") 
                    Write-Host $takethat
                    
                    Write-Host ""

                }

                $count = $count + 1
                $PreviousApp = $App
                                
                if ($AllApp[-1] -like "$begappid*")
                {

                    $howmanyapps = ($AllApp.Count)
                    if ($howmanyapps -EQ "-1")
                    {
                        write-host ""
                        Write-Host "No apps found to be install" -ForegroundColor Red
                    }
                    Else
                    {
                        $count = $count
                        write-host ""
                        Write-Host "Aplication $count of $howmanyapps installed" -ForegroundColor Yellow

                        $time = [regex]::Match($item, $timePattern).Groups[1].Value
                        $timelastapp = ($time.Split("."))[0] 
                        $totaltime = HowLong $StartAppsInst $timelastapp
                        Write-Host $totaltime
                    }

                    
                    exit 
                }       
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
                    
                    #write-host $Mulitimelogend -ForegroundColor Yellow                            

                    $MultiAppEnd = $true
                    $MultiAppID = $idarr[$i]
                }

                if ($wtf.contains($MultiAppID))
                {
                    $wtfcheck = $true
                }
                else
                {
                    $wtfcheck = $null
                }

                if (($MultiAppEnd -eq $true) -and ($wtfcheck -ne $true))
                {
                    #write-host $MultiAppEnd
                    $wtf = $wtf + $MultiAppID
                    $takethat = HowLong $Mulitimelogstart $Mulitimelogend            
                    $takethatdownload = HowLong $timeAppdownloadstart $timeAppCheckHashstart
                    $takethathash = HowLong $timeAppCheckHashstart $timeAppDecrypstart
                    $takethatunzip = HowLong $timeAppUnzipstart $timeAppInststart
                    $takethatinst = HowLong $timeAppInststart $timelogend
   
                    $App = LogAppName $MultiAppID
                    $AppCtrl = $App
                    if (($App -ne $null) -and ($takethat -notlike "*-*") -and ($PreviousApp -notlike $App)  -and ($takethat -notlike "*00:00:0*"))
                    {
                        Write-Host $App -ForegroundColor Green  
                        Write-Host "Download Time" $takethatdownload.Replace("Total Time: ","") 
                        Write-Host "Hash Time" $takethathash.Replace("Total Time: ","") 
                        Write-Host "Unzip Time" $takethatunzip.Replace("Total Time: ","") 
                        Write-Host "Install Time" $takethatinst.Replace("Total Time: ","") 
                        Write-Host $takethat
                        Write-Host ""
                        $count = $count + 1
                        $PreviousApp = $App                           
                             
                    }                   
                    $MultiAppEnd = $false
                    $AppLaunchStatus = $null
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

$App = LogAppName $singleID

if ($AppDownloadStatus -eq "Begin")
{   
    Write-host ""
    Write-Host "Downloading App" -ForegroundColor Yellow
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

$howmanyapps = ($AllApp.Count)
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
