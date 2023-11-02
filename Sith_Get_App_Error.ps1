cls
$AllApp = $null

$getfile = Get-ChildItem -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs -Filter Int*.log


#$readfile = Get-Content -Path C:\data\IntuneManagementExtension.log
write-host "Apps to be install " -ForegroundColor Green

foreach ($item in $getfile)
{
    $readfile = Get-Content -Path $item.fullname


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
}

IF ($foundError.count -ne 0)
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$foundError*")
        {
            write-host "Found error " -ForegroundColor Red
            write-host $item
        }
    }
}