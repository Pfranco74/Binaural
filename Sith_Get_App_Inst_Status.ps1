cls
$AllApp = $null
#$readfile = Get-Content -Path 'c:\Programdata\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log'
$readfile = Get-Content -Path C:\data\IntuneManagementExtension.log
write-host "Apps to be install " -ForegroundColor Green
foreach ($item in $readfile)
{
    if ($item -like "* In EspPhase: DeviceSetup. App*")
    {
        $AppID = $item.Substring(60,40)
        $AppNAme = ($item.Substring(128)).split("]")[0]
        $AppInst = "AppID: " + $AppID + " AppName: " + $AppNAme       
        $AllApp = @($AppInst) + $AllApp
        Write-Output $AppInst    
    }
}

$AppDownloadStatus= $null
$AppDownload = "Downloading app"
$AppUnzippingStatus= $null
$AppUnzipping = "Start unzipping"
$AppLaunchStatus= $null
$AppLaunch = "Launch Win32AppInstaller in machine session"

foreach ($item in $readfile)
{
    if (($item -like "*$AppDownload*") -and $AppDownloadStatus -eq $null)
    {
        $pharse = $item.Substring(53,36)
        $AppDownloadId = $Item.Substring(53,36)   
        $AppDownloadStatus = "Begin"                     
    }
    
    if ($item -like "*Notified DO Service the job is complete*")
    {
         $AppDownloadStatus = $null                     
    }  

    if (($item -like "*$AppUnzipping*") -and $AppUnzippingStatus -eq $null)
    {
        $AppUnzippingStatus = "Begin"                   
    }

    if ($item -like "*Cleaning up staging content*")
    {
         $AppUnzippingStatus = $null                     
    }  

    if (($item -like "*$AppLaunch*") -and $AppLaunchStatus -eq $null)
    {
        $AppLaunchStatus = "Begin"                   
    }

    if ($item -like "*Completed detectionManager SideCarFileDetectionManager, applicationDetectedByCurrentRule: True*")
    {
         $AppLaunchStatus = $null                     
    } 
}



if ($AppDownloadStatus -eq "Begin")
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$AppDownloadId*")
        {
            Write-Host $AppDownload -ForegroundColor Red
            write-host $item
        }
    }
    
}

if ($AppUnzippingStatus -ne "Begin")
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$AppDownloadId*")
        {
            Write-Host $AppUnzipping -ForegroundColor Red
            write-host $item
        }
    }
    
}

if ($AppLaunchStatus -eq "Begin")
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$AppDownloadId*")
        {
            Write-Host $AppLaunch -ForegroundColor Red
            write-host $item
        }
    }
    
}