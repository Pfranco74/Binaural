cls
$AllApp = $null
$readfile = Get-Content -Path 'c:\Programdata\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log'
#$readfile = Get-Content -Path C:\Data\IntuneManagementExtension.log
#write-host "Apps to be install " -ForegroundColor Green
foreach ($item in $readfile)
{
    if ($item -like "* In EspPhase: DeviceSetup. App*")
    {
        $AppID = $item.Substring(60,40)
        $AppNAme = ($item.Substring(128)).split("]")[0]
        $AppInst = "AppID: " + $AppID + " AppName: " + $AppNAme       
        $AllApp = @($AppInst) + $AllApp
        # Write-Output $AppInst    
    }
}

$AppDownloadStatus= $null
$AppDownload = "Downloading app"
$AppHash = 'Starts verifying encrypted hash'
$AppHashStatus = $null
$AppUnzippingStatus= $null
$AppUnzipping = "Start unzipping"
$AppLaunchStatus= $null
$AppLaunch = "Launch Win32AppInstaller in machine session"

foreach ($item in $readfile)
{
    if (($item -like "*$AppDownload*") -and $AppDownloadStatus -eq $null)
    {
        $timelog = ((($item.Split(" ")[7]).split("=")[-1]).split(".")[0]).substring(1,8)
        $datelog = ((($item.Split(" ")[8]).split("=")[-1]).split(".")[0]).substring(1,10)

        $AppDownloadId = $Item.Substring(53,36)   
        $AppDownloadStatus = "Begin"                     
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
    }
}



if ($AppDownloadStatus -eq "Begin")
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$AppDownloadId*")
        {
            $logdate = "Start at " + $datelog + " " + $timelog

            Write-Host $AppDownload -ForegroundColor Red
            Write-Host $logdate            
            write-host $item
        }
    }
    
}

if ($AppHashStatus -EQ "Begin")
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$AppDownloadId*")
        {
            Write-Host $AppHash -ForegroundColor Red
            Write-Host $logdate
            write-host $item
        }
    }
    
}

if ($AppUnzippingStatus -EQ "Begin")
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$AppDownloadId*")
        {
            Write-Host $AppUnzipping -ForegroundColor Red
            Write-Host $logdate
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
            Write-Host $logdate
            write-host $item
        }
    }
    
}
