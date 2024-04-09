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
        $AllApp = @($AppInst) + $AllApp

    }
    
    Return $AllApp
}

function LogAppName ($Block,$AppControl)
{
   if ($AppControl -notlike "*$Block*")
   {
        foreach ($item in $AllApp)
        {
            if ($item -like "*$Block*")
            {                
                Return $item.Split(";")[1]
            }
        }   
   }
   else
   {
    Return $null
   }
   
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

$getfile = Get-ChildItem -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs -Filter Intune*.log
#$getfile = Get-ChildItem -Path C:\Data\ -Filter Intune*.log
#Write-host ""write-host "Apps to be install " -ForegroundColor Green

foreach ($item in $getfile)
{
    $readfile = Get-Content -path $item.FullName
    $AllApp = AppstobeInstall $item.FullName 
    #write-host $Allapp -ForegroundColor Green             
}


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

foreach ($item in $readfile)
{   
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

    if (($item -like "*Completed detectionManager SideCarFileDetectionManager, applicationDetectedByCurrentRule: True*") -or ($item -like "*Completed detectionManager SideCarRegistryDetectionManager, applicationDetectedByCurrentRule: True*"))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value
        $timelog = ($time.Split("."))[0]            
        $datelog = $date 

        $AppLaunchStatus = $null  

        $timeend = $timelog  
        $takethat = HowLong $timestart $timeend
        $App = LogAppName $AppDownloadId $AppCtrl
        $AppCtrl = $App
        if (($App -ne $null) -and ($takethat -notlike "*-*")-and ($PreviousApp -notlike $App))
        {
            Write-Host $App -ForegroundColor Green  
            Write-Host $takethat    
            $count = $count + 1
            $PreviousApp = $App        
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