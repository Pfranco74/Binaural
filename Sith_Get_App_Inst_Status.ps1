﻿cls
Remove-Variable * -ErrorAction SilentlyContinue
$AllApp = $null
$getfile = Get-ChildItem -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs -Filter Intune*.log
#$getfile = Get-ChildItem -Path C:\Data\ -Filter Intune*.log
#Write-host ""write-host "Apps to be install " -ForegroundColor Green

foreach ($item in $getfile)
{
    $readfile = Get-Content -path $item.FullName
    foreach ($item1 in $readfile)
    {
        

        if ($item1 -like "* In EspPhase: DeviceSetup. App*")
        {
        $AppID = $item1.Substring(60,40)
        $AppNAme = ($item1.Substring(128)).split("]")[0]
        $AppInst = "AppID: " + $AppID + " AppName: " + $AppNAme       
        $AllApp = @($AppInst) + $AllApp
        #Write-Output $AppInst    
    }

    }
}

function AppID ($Block,$AppControl)
{
   if ($AppControl -notlike "*$Block*")
   {
        foreach ($item in $AllApp)
        {
            if ($item -like "*$Block*")
            {
                Return $item
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
    
    #write-host $item
    if (($item -like "*$AppDownload*") -and $AppDownloadStatus -eq $null)
    {     
        if ($item.Split(" ")[7] -like "*time*")
        {
            $timelog = ((($item.Split(" ")[7]).split("=")[-1]).split(".")[0]).substring(1,8)
            $datelog = ((($item.Split(" ")[8]).split("=")[-1]).split(".")[0]).substring(1,10)
            $AppDownloadId = $Item.Substring(53,36)               
        }   
        else
        {
            $timelog = ((($item.Split(" ")[20]).split("=")[-1]).split(".")[0]).substring(1,8)
            $datelog = ((($item.Split(" ")[21]).split("=")[-1]).split(".")[0]).substring(1,10)
            $AppDownloadId = $Item.Substring(45,36)             
        }
        $AppDownloadStatus = "Begin"
        $timestart = $timelog
        
               
    }

    if ($item -like "*Notified DO Service the job is complete*")
    {
        $timelog = ((($item.Split(" ")[6]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[7]).split("=")[-1]).split(".")[0]).substring(1,10)
        $AppDownloadStatus = $null                        
    }  


    if (($item -like "*$AppHash*") -and $AppHashStatus -eq $null)
    {
        $timelog = ((($item.Split(" ")[4]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[5]).split("=")[-1]).split(".")[0]).substring(1,10)
        $AppHashStatus = "Begin"                   
    }

    if ($item -like "*download and decryption is successfully done*")
    {
        $timelog = ((($item.Split(" ")[8]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[9]).split("=")[-1]).split(".")[0]).substring(1,10)
        $AppHashStatus = $null                     
    }  

    if (($item -like "*$AppUnzipping*") -and $AppUnzippingStatus -eq $null)
    {
        $timelog = ((($item.Split(" ")[2]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[3]).split("=")[-1]).split(".")[0]).substring(1,10)
        $AppUnzippingStatus = "Begin"                   
    }

    if ($item -like "*Cleaning up staging content*")
    {
        $timelog = ((($item.Split(" ")[9]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[10]).split("=")[-1]).split(".")[0]).substring(1,10)
        $AppUnzippingStatus = $null                     
    }  

    if (($item -like "*$AppLaunch*") -and $AppLaunchStatus -eq $null)
    {
        $timelog = ((($item.Split(" ")[5]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[6]).split("=")[-1]).split(".")[0]).substring(1,10)

        $AppLaunchStatus = "Begin"                   
    }

    if (($item -like "*Completed detectionManager SideCarFileDetectionManager, applicationDetectedByCurrentRule: True*") -or ($item -like "*Completed detectionManager SideCarRegistryDetectionManager, applicationDetectedByCurrentRule: True*"))
    {
        $timelog = ((($item.Split(" ")[5]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[6]).split("=")[-1]).split(".")[0]).substring(1,10)
        $AppLaunchStatus = $null  

        $timeend = $timelog  
        $takethat = HowLong $timestart $timeend
        $App = AppID $AppDownloadId $AppCtrl
        $AppCtrl = $App
        if (($App -ne $null) -and ($takethat -notlike "*-*"))
        {
            Write-Host $App -ForegroundColor Green  
            Write-Host $takethat            
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


$App = AppID $AppDownloadId

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
