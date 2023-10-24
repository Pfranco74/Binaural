cls
$AllApp = $null
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

    $erro = "NewValue"":""Error"
    if ($item -like "*$erro*")
    {
         $foundError = $item.Substring(69,36)
    }
}

foreach ($item in $AllApp)
{
    if ($item -like "*$foundError*")
    {
        write-host "Found error "  -ForegroundColor Red
        write-host $item
    }
}

#MBCP - CORE - AutoBranding), start downloading..