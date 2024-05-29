# Ver 01.00 Rev.LFC 29052024
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


$wtf = "WTF-"
$wtfcheck = $null
$AppDownloadStatus = $null
$portalapp = $null

$MultiAppBeg = "<![LOG[[Win32App][EspManager] Updating ESP tracked install status from NotInstalled to InProgress for application"
$MultilAppDownload = "<![LOG[[Win32App] Downloading app on session 0. App"
$MultilAppDownloadStart = "<![LOG[[Win32App] Content cache miss for app (id"
$MultiAppHash = "<![LOG[[Win32App] Starts verifying encrypted hash]"
$MultiAppUnZip = "<![LOG[[Win32App] Start unzipping.]LOG]"
$MultiAppLaunch = "<![LOG[[Win32App] Launch Win32AppInstaller in machine session"
$MultiAppEnd = "<![LOG[[Win32App][EspManager] Updating ESP tracked install status from InProgress to Completed for application"


$AppDownloadBytes = "bytes 0/0" 
$portalappbeg = "<![LOG[[Package Manager] BytesRequired - 0BytesDownloaded - 0DownloadProgress - 1InstallationProgress - 0"
$dateportalappend = "<![LOG[[WinGetLocalProgressAndResultSender] Changing app state to download complete"
$AppDownloadPER = "via DO, bytes "
$AppDownloadCDN = "via CDN, bytes "



foreach ($item in $readfile)
{   

    if ($item.StartsWith($MultiAppBeg) -eq $true)
    {      
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultiApplicationIDstart = ($time.Split("."))[0]        
        $dateMultiApplicationIDstart = $date
        $MultiApplicationID = $item.Substring(114,36)
    }

    if ($item.StartsWith($MultilAppDownload) -eq $true)
    {      
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultilAppDownloadstart = ($time.Split("."))[0]        
        $dateMultilAppDownloadstart = $date

        $CheckMultilAppDownload = $true

    }

    if ($item.StartsWith($MultilAppDownloadStart) -eq $true)
    {      
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultilAppDownloadstartbeg = ($time.Split("."))[0]        
        $dateMultilAppDownloadstartbeg = $date

        $CheckMultilAppDownloadstart = $true

    }

    if (($item.StartsWith($MultiAppHash) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultiAppHashstart = ($time.Split("."))[0]        
        $dateMultiAppHashstart = $date
        $CheckMultilAppDownloadstart = $false
        $CheckMultiAppHash = $true
    }


    if (($item.StartsWith($MultiAppUnZip) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultiAppUnZipstart = ($time.Split("."))[0]        
        $dateMultiAppUnZipstart = $date
        $CheckMultilAppDownloadstart = $false
        $CheckMultiAppHash = $false
        $CheckMultiAppUnZip = $true

    }


    if (($item.StartsWith($MultiAppLaunch) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultiAppLaunchtstart = ($time.Split("."))[0]        
        $dateMultiAppLaunchpstart = $date
        $CheckMultilAppDownloadstart = $false
        $CheckMultiAppHash = $false
        $CheckMultiAppUnZip = $false
        $CheckMultiAppLaunch = $true
    }


    if ($item.StartsWith($MultiAppEnd) -eq $true)
    {        
        $endappOK = $true
        
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultiAppEndend = ($time.Split("."))[0]        
        $dateMultiAppEndend = $date        
        $CheckMultilAppDownloadstart = $false
        $CheckMultiAppHash = $false
        $CheckMultiAppUnZip = $false
        $CheckMultiAppLaunch = $false
        $downloadper = $null
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



    if (($endappOK -eq $true))
    {
            $endappOK = $false
            $takethat = HowLong $timeMultiApplicationIDstart $timeMultiAppEndend
            $takethatdownload = HowLong $timeMultilAppDownloadstart $timeMultiAppHashstart
            $takethathash = HowLong $timeMultiAppHashstart $timeMultiAppUnZipstart
            $takethatunzip = HowLong $timeMultiAppUnZipstart $timeMultiAppLaunchtstart
            $takethatinst = HowLong $timeMultiAppLaunchtstart $timeMultiAppEndend
            if ($portalapp -eq $true)
            {
                $takethatinst = HowLong $timeportalappbeg $timeportalappend
            }
            
            $App = LogAppName $MultiApplicationID
            $AppCtrl = $App
            if (($App -ne $null) -and ($takethat -notlike "*-*") -and ($PreviousApp -notlike $App)  -and ($takethat -notlike "*00:00:0*"))
            {
                if ($portalapp -ne $true)
                {
                    Write-Host $App -ForegroundColor Green  
                    #Write-Host "Download Time" $takethatdownload.Replace("Total Time: ","") 
                    #Write-Host "Hash Time" $takethathash.Replace("Total Time: ","") 
                    #Write-Host "Unzip Time" $takethatunzip.Replace("Total Time: ","") 
                    #Write-Host "Install Time" $takethatinst.Replace("Total Time: ","") 
                    Write-Host $takethat
                    
                    Write-Host ""
                }
                else
                {
                    $portalapp = $null

                    Write-Host $App -ForegroundColor Green  
                    #Write-Host "Install Time" $takethatinst.Replace("Total Time: ","") 
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
                        #write-host ""
                        #Write-Host "No apps found to be install" -ForegroundColor Red
                    }
                    Else
                    {
                        $count = $count
                        #write-host ""
                        #Write-Host "Aplication $count of $howmanyapps installed" -ForegroundColor Yellow

                        $time = [regex]::Match($item, $timePattern).Groups[1].Value
                        $timelastapp = ($time.Split("."))[0] 
                        $totaltime = HowLong $StartAppsInst $timelastapp
                        #Write-Host $totaltime
                    }

                    
                    #exit 
                }       
            }                   
        }


    if (($item -like "*$AppDownloadPER*") -or ($item -like "*$AppDownloadCDN*"))
    {
        $line = $item.Split(" ")

        foreach ($item in $line)
        {
            if (($item -like "*/*") -and ($item -notlike "*//*"))
            {
                $atual = $item.Split("/")[0]               
                $total = $item.Split("/")[-1]
                if (($atual -ne 0) -and ($total -ne 0))
                {   
                    try
                    {              
                        $downloadper = ($atual/$total).ToString("P")                  
                    }
                    catch
                    {
                        Write-host "Error calculating precentage"                    
                    }
                }
            }
        }       
    }
}

$App = LogAppName $MultiApplicationID

if ($count -lt $howmanyapps)
{
    

if ($CheckMultilAppDownload -eq $true)
{   
    Write-host ""
    Write-Host "Downloading App" -ForegroundColor Yellow
    Write-Host $logdate            
    write-host $App   
    Write-Host $downloadper
}

if ($CheckMultiAppHash -EQ $true)
{
    Write-host ""
    Write-Host $AppHash -ForegroundColor Yellow
    Write-Host $logdate
    write-host $App   
}

if ($CheckMultiAppUnZip -EQ $true)
{
    Write-host ""
    Write-Host $AppUnzipping -ForegroundColor Yellow
    Write-Host $logdate
    write-host $App   
}

if ($CheckMultiAppLaunch -eq $true)
{
    Write-host ""
    Write-Host $AppLaunch -ForegroundColor Yellow
    Write-Host $logdate
    write-host $App   
}

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