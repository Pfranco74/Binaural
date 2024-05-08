cls
Remove-Variable * -ErrorAction SilentlyContinue
$AllApp = $null

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

function FoundError ($logFilePathIME)
{    
    $IME = "NewValue"":""Error"
    $logLinesIME = Get-Content -Path $logFilePathIME | Select-String -Pattern $IME
    
    # --[ Define a regular expression pattern to extract the log content and other information ]
    $logPattern  = '\[LOG\[(.*?)\]LOG\]'

    # --[ Outputting extracted information ]
    foreach ($line in $logLinesIME)
    {
        $log = [regex]::Match($line, $logPattern).Groups[1].Value       
        $positionid = $log.IndexOf("app with id: ")        
        $appid = (($log.Substring($positionid+1)).split(" "))[3]
        
        $AppIdError = $appid
    }
    
    Return $AppIdError
}

$getfile = Get-ChildItem -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs -Filter Int*.log
#$getfile = Get-ChildItem -Path C:\Data\ -Filter Intune*.log

foreach ($item in $getfile)
{
    $readfile = Get-Content -path $item.FullName
    $AllApp = AppstobeInstall $item.FullName 
    #write-host $Allapp -ForegroundColor Green             

    $foundError = FoundError $item.FullName 

}

IF ($foundError.count -ne 0)
{
    foreach ($item in $AllApp)
    {
        if ($item -like "*$foundError*")
        {
            write-host "Found error " -ForegroundColor Red
            write-host $item.Split(";")[1]
        }
    }
}