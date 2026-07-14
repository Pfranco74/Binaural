$scriptversion = '20241106'
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
    Get-Content -Path C:\data\Intune\logs\AppWorkload*.log | Set-Content $JoinedFile    
}
else
{
    $JoinedFile = $env:USERPROFILE + "\AllIntuneManagementExtension.log"
    Get-Content -Path C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload*.log | Set-Content $JoinedFile       
}



$readfile = Get-Content -Path $JoinedFile
$AllApp = AppstobeInstall $JoinedFile 
#write-host $Allapp -ForegroundColor Green     


$wtf = "WTF-"
$wtfcheck = $null
$AppDownloadStatus = $null
$portalapp = $null

$MultiAppBeg = "<![LOG[[Win32App][DownloadActionHandler] Handler invoked for policy with id"
$MultilAppDownload = "<![LOG[[Win32App] Downloading app on session 0. App"
$MultilPorDownload = "<![LOG[[Package Manager] BytesRequired - 0BytesDownloaded - 0DownloadProgress - 1InstallationProgress - 0"
$MultilAppDownloadStart = "<![LOG[[Win32App] Content cache miss for app (id"
$MultiAppHash = "<![LOG[[Win32App] Starts verifying encrypted hash]"
$MultiAppUnZip = "<![LOG[[Win32App] Start unzipping.]LOG]"
$MultiAppLaunch = "<![LOG[[Win32App] Launch Win32AppInstaller in machine session"
$MultiAppEnd = "<![LOG[[Win32App][EspManager] Updating ESP tracked install status from InProgress to Completed for application"
$MultiAppEnd2 = "resulted in action status: Success and detection state: Detected"

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

        $MultiApplicationID = $item.Split(" ")[7]


    }

    if (($item.StartsWith($MultilAppDownload) -eq $true))
    {      
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultilAppDownloadstart = ($time.Split("."))[0]        
        $dateMultilAppDownloadstart = $date

        $CheckMultilAppDownload = $true

    }

    if (($item.StartsWith($MultilAppDownloadStart) -eq $true))
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


    if (($item.StartsWith($MultiAppEnd) -eq $true) -or ($item.Contains($MultiAppEnd2) -eq $true))
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



    if (($item.StartsWith($MultilPorDownload) -eq $true))
    {
        $date = [regex]::Match($item, $datePattern).Groups[1].Value
        $time = [regex]::Match($item, $timePattern).Groups[1].Value

        $timeMultilPorDownloadstart = ($time.Split("."))[0]   
        $dateMultilPorDownloadstart = $date

        $portalapp = $true
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
                $takethatinst = HowLong $timeMultilPorDownloadstart $timeMultiAppEndend
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

    if ($item.StartsWith($MultilPorDownload) -eq $true)
    {
        $TransferBytes = ($item.Split("]LOG]")[4]).split(" ")[-1]
        $x = $TransferBytes
      
    }
}

$App = LogAppName $MultiApplicationID

if ($count -lt $howmanyapps)
{
    

if ($CheckMultilAppDownloadstart -eq $true)
{   
    Write-host ""
    Write-Host "Downloading App $app" -ForegroundColor Yellow
    Write-Host "Start at $timeMultilAppDownloadstartbeg"
    $now = (Get-Date).ToString("HH:mm:ss")
    Write-Host "Now is   $now" -ForegroundColor Magenta
    Write-Host "The precentage is $downloadper" -ForegroundColor Gray
}

if ($CheckMultiAppHash -EQ $true)
{
    Write-host ""
    Write-Host "Validating HASH $app" -ForegroundColor Yellow
    Write-Host "Start at $timeMultiAppHashstart " 
    $now = (Get-Date).ToString("HH:mm:ss")
    Write-Host "Now is   $now" -ForegroundColor Magenta
}

if ($CheckMultiAppUnZip -EQ $true)
{
    Write-host ""
    Write-Host "Unzip APP $App" -ForegroundColor Yellow
    Write-Host "Start at $timeMultiAppUnZipstart "
    $now = (Get-Date).ToString("HH:mm:ss")
    Write-Host "Now is   $now" -ForegroundColor Magenta
}

if ($CheckMultiAppLaunch -eq $true)
{
    Write-host ""
    Write-Host "Launch App Installer $app" -ForegroundColor Yellow
    Write-Host "Start at $timeMultiAppLaunchtstart"
    $now = (Get-Date).ToString("HH:mm:ss")
    Write-Host "Now is   $now" -ForegroundColor Magenta
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
    Write-Host "Aplication $count of $howmanyapps installed" -ForegroundColor White
}


# SIG # Begin signature block
# MIIfPAYJKoZIhvcNAQcCoIIfLTCCHykCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPtYKa7YguP9kgtau2t8yVED2
# BOagghl6MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
# AQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz
# 7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS
# 5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7
# bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfI
# SKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jH
# trHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14
# Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2
# h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt
# 6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPR
# iQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ER
# ElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4K
# Jpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAd
# BgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAC
# hjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRV
# HSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyh
# hyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO
# 0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo
# 8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++h
# UD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5x
# aiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGczCCBVug
# AwIBAgITIAADx1drX2DfBPsXiQABAAPHVzANBgkqhkiG9w0BAQsFADBQMRMwEQYK
# CZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPyLGQBGRYHYmNwY29ycDEgMB4GA1UE
# AxMXQkNQIEdyb3VwIElzc3VpbmcgQ0EgMDEwHhcNMjQwODEyMTQwNDQxWhcNMjYw
# ODEyMTQwNDQxWjBUMQswCQYDVQQGEwJQVDEPMA0GA1UEBxMGTGlzYm9hMRcwFQYD
# VQQKEw5NaWxsZW5uaXVtIEJDUDEbMBkGA1UEAwwSRW5kcG9pbnRTV19TaWduaW5n
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvFn4YZnZALAerpNoEJY/
# kcS0Uk7C2wDEGtZ0WEsvAgIAdCmhNbKecRs163yuHqPbE1CZZLc8YusxZ136nP3P
# CyEhy3qTKLSSPzYuMXqBKUt5wZsiIjZLqmVVRD+nBG5j8uRyqYUq9rn8/k6AVk1A
# 3SDl+9Z0TnKZpgeCBZ9kCEr6mQHcZgdRakzU1Lwzw7QC8V01E7+qpHVqDr11AyWz
# COwZfh67eTF6nwivECiePCjw5pZAFJFe550Lf+CPzjSnI2SfBG78c8mxwiFP2EMN
# 8SysyoyY+6z5+UrvKYgjdQlWvFHYcJJvoiN6nCTmX2JaDXZyZrqoG885TgsUyUCt
# cQIDAQABo4IDQDCCAzwwPQYJKwYBBAGCNxUHBDAwLgYmKwYBBAGCNxUIg63yDoKd
# unaRhSOF47xxhuXJE4FBhsOHZILXmBACAWQCAQ4wEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwCwYDVR0PBAQDAgeAME0GA1UdIARGMEQwQgYKKwYBBAGBgiQBAzA0MDIGCCsG
# AQUFBwIBFiZodHRwOi8vcGtpLmJjcC5wdC9kb2MvR3J1cG9CQ1BDUDAyLnBkZjAb
# BgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQbKmGj3+JhrNYx
# 7EldJelbU63MDzAfBgNVHSMEGDAWgBQJ3og3Fr8xWygusRL3v/SLEMMFcjCCARUG
# A1UdHwSCAQwwggEIMIIBBKCCAQCggf2GLWh0dHA6Ly9wa2kuYmNwLnB0L2NybC9C
# Q1BHcm91cElzc3VpbmdDQTAxLmNybIaBy2xkYXA6Ly8vQ049QkNQJTIwR3JvdXAl
# MjBJc3N1aW5nJTIwQ0ElMjAwMSxDTj1TRVRQU0ZJS0lDMDEsQ049Q0RQLENOPVB1
# YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRp
# b24sREM9YmNwY29ycCxEQz1uZXQ/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9i
# YXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50MIIBEgYIKwYBBQUH
# AQEEggEEMIIBADA9BggrBgEFBQcwAoYxaHR0cDovL3BraS5iY3AucHQvY2VydC9C
# Q1BHcm91cElzc3VpbmdDQTAxKDEpLmNydDCBvgYIKwYBBQUHMAKGgbFsZGFwOi8v
# L0NOPUJDUCUyMEdyb3VwJTIwSXNzdWluZyUyMENBJTIwMDEsQ049QUlBLENOPVB1
# YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRp
# b24sREM9YmNwY29ycCxEQz1uZXQ/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENs
# YXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQADggEBACbH
# tjOKXjmSGSNKmIp90ImFELKeAxEvaxvRkccarF0hInsTrsMXTnuabr0hk5yIpeqF
# YfAuk/CIJICLihitTYOuZ2l4EX/u3/Zy+wuMTGQep4dhkWt+aUpdwHsItNVnzggD
# IyQmYVlRf32PmDD548+nwdyL5M4a70ZgpEYURFfNj0eK/bts1Dic06rjHgMPblCQ
# 3YAy8YTEQeH6QQaXh0hz99tju7yPZ6FoYnhFPNpVdZa1Q8q1G5nF2Jjt+j1ODfKl
# R4GTXO1KOtrVwMUiPJMspYp8EL9Xo8OJKEdVIm76zz10dalk8O4LvKbAjOZj/NWo
# jBT9XALjML5DAZxciGgwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0G
# CSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0
# IFRydXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBp
# bmcgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJ
# UVXHJQPE8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+e
# DzMfUBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47q
# UT3w1lbU5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL
# 6IRktFLydkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c
# 1eYbqMFkdECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052
# FVUmcJgmf6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+
# onP65x9abJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/w
# ojzKQtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1
# eSuo80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uK
# IqjBJgj5FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7p
# XcheMBK9Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgw
# FoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7
# x1Bd4ksp+3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGId
# DAiCqBa9qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7g
# iqzl/Yy8ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6
# wCeCRK6ZJxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx
# 2cYTgAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5kn
# LD0/a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3it
# TK37xJV77QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7
# HhmLNriT1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUV
# mDG0YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKm
# KYcJRyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8
# MIIGvDCCBKSgAwIBAgIQC65mvFq6f5WHxvnpBOMzBDANBgkqhkiG9w0BAQsFADBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5n
# IENBMB4XDTI0MDkyNjAwMDAwMFoXDTM1MTEyNTIzNTk1OVowQjELMAkGA1UEBhMC
# VVMxETAPBgNVBAoTCERpZ2lDZXJ0MSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3Rh
# bXAgMjAyNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL5qc5/2lSGr
# ljC6W23mWaO16P2RHxjEiDtqmeOlwf0KMCBDEr4IxHRGd7+L660x5XltSVhhK64z
# i9CeC9B6lUdXM0s71EOcRe8+CEJp+3R2O8oo76EO7o5tLuslxdr9Qq82aKcpA9O/
# /X6QE+AcaU/byaCagLD/GLoUb35SfWHh43rOH3bpLEx7pZ7avVnpUVmPvkxT8c2a
# 2yC0WMp8hMu60tZR0ChaV76Nhnj37DEYTX9ReNZ8hIOYe4jl7/r419CvEYVIrH6s
# N00yx49boUuumF9i2T8UuKGn9966fR5X6kgXj3o5WHhHVO+NBikDO0mlUh902wS/
# Eeh8F/UFaRp1z5SnROHwSJ+QQRZ1fisD8UTVDSupWJNstVkiqLq+ISTdEjJKGjVf
# IcsgA4l9cbk8Smlzddh4EfvFrpVNnes4c16Jidj5XiPVdsn5n10jxmGpxoMc6iPk
# oaDhi6JjHd5ibfdp5uzIXp4P0wXkgNs+CO/CacBqU0R4k+8h6gYldp4FCMgrXdKW
# fM4N0u25OEAuEa3JyidxW48jwBqIJqImd93NRxvd1aepSeNeREXAu2xUDEW8aqzF
# QDYmr9ZONuc2MhTMizchNULpUEoA6Vva7b1XCB+1rxvbKmLqfY/M/SdV6mwWTyeV
# y5Z/JkvMFpnQy5wR14GJcv6dQ4aEKOX5AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8E
# BAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNV
# HSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2F
# L3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFJ9XLAN3DigVkGalY17uT5IfdqBbMFoG
# A1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsG
# AQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJ
# KoZIhvcNAQELBQADggIBAD2tHh92mVvjOIQSR9lDkfYR25tOCB3RKE/P09x7gUsm
# Xqt40ouRl3lj+8QioVYq3igpwrPvBmZdrlWBb0HvqT00nFSXgmUrDKNSQqGTdpjH
# sPy+LaalTW0qVjvUBhcHzBMutB6HzeledbDCzFzUy34VarPnvIWrqVogK0qM8gJh
# h/+qDEAIdO/KkYesLyTVOoJ4eTq7gj9UFAL1UruJKlTnCVaM2UeUUW/8z3fvjxhN
# 6hdT98Vr2FYlCS7Mbb4Hv5swO+aAXxWUm3WpByXtgVQxiBlTVYzqfLDbe9PpBKDB
# fk+rabTFDZXoUke7zPgtd7/fvWTlCs30VAGEsshJmLbJ6ZbQ/xll/HjO9JbNVekB
# v2Tgem+mLptR7yIrpaidRJXrI+UzB6vAlk/8a1u7cIqV0yef4uaZFORNekUgQHTq
# ddmsPCEIYQP7xGxZBIhdmm4bhYsVA6G2WgNFYagLDBzpmk9104WQzYuVNsxyoVLO
# bhx3RugaEGru+SojW4dHPoWrUhftNpFC5H7QEY7MhKRyrBe7ucykW7eaCuWBsBb4
# HOKRFVDcrZgdwaSIqMDiCLg4D+TPVgKx2EgEdeoHNHT9l3ZDBD+XgbF+23/zBjeC
# txz+dL/9NWR6P2eZRi7zcEO1xwcdcqJsyz/JceENc2Sg8h3KeFUCS7tpFk7CrDqk
# MYIFLDCCBSgCAQEwZzBQMRMwEQYKCZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPy
# LGQBGRYHYmNwY29ycDEgMB4GA1UEAxMXQkNQIEdyb3VwIElzc3VpbmcgQ0EgMDEC
# EyAAA8dXa19g3wT7F4kAAQADx1cwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFE77+nuQnaSW8Zuq
# LtN5sPTQJVHnMA0GCSqGSIb3DQEBAQUABIIBAJ7Zpr5XwXVpNowxFlg2Z1IhUepB
# tD0MS2ODq4YKGgjNpVKbS9u+QO525G4Ex/MJN8kkBs9RBK8HOB+pKrXHEB/3kE+D
# MNuZ85U23ZVhciykUzHGqmnVcQKaRIFE14sMIOBKrAWTmIqyr4LRE9ceIOtNM523
# Ib/lbsxwwYG0tlmU4+y5aNxn8dUHxSEmZ58gztsUG+G/TWU072HViKJzmorP+4j1
# 5RpxsSaimgppESaQLcNvk67fES67JlDWVQndr0ZrIXWGAsBAfXwkMr8jDPNp7DI/
# X8PN5cRXYQY/yAoUBOV/Qn+P4ymAS0uoaKhZhIv4r0DeSJ0p/XzJ38VFog6hggMg
# MIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQg
# RzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/lYfG+ekE
# 4zMEMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAc
# BgkqhkiG9w0BCQUxDxcNMjQxMTA3MTkxNjMwWjAvBgkqhkiG9w0BCQQxIgQgXFQk
# XAC7FTllMruzXXEg0dT4r3T6CbDnrRkmi6EqnZgwDQYJKoZIhvcNAQEBBQAEggIA
# fBtzoF7lmNbEodLXEYTV5ONjEC+YnA/Spr0UnV4spQOThpoR9BhGTzKDwQ0Db09v
# LAZK7A3ppt6Bj9ytvdpC9k+NJZlYr+aaGV9LpRp0b0isUB5G5nxDnEiT9mJVmCLh
# GQasPBNW7r65L9AV3kNL8jpGo80yO4o8iL5wjMaxYb+Q3k+frDb9U++GO25fqo9Q
# dbGr3gaV/4qQKsmCW//fUarxupYdQbii+OjfGT2VjhK3RlIwSubBOYS+hrO4vB68
# YdSmLGVLVO08lIGrRp4N7xB6U7wcOIL9cck8/R6+AaisR1GP6rodmG2IozKvWC8J
# S7LDBP5A5I9INb/kHGPu9T7tkqQUjqCFvdqWnqMRjkWaepY0poCLdJ5oFE8gukDF
# A1xB1DWPHB0xeNBaiiE05IigXtYg/0Fb/JnTZI+bJ1DOMlwnPUDS+1go0zzzSZmN
# LmHIV4EHnMmTayKlZf422/ovtMuHSt3n2K58mZvpN4QrByTO/WN00SsUhRg7I5gL
# WrOCdzdFg6QRJTakWGna359uSDs0TfMm4Y2ie5rq2IB8iBUQ2X0tKU+m54IkWP5F
# WqYtj9JZlWI+XwrdCuSVEhBHI930YAMM0HAoGeIwii5TV7cx8Y9hjkiSbcQUa7uD
# qNk9wRizs9LgGnWgN1T2AjL/6RpPuyf5yDIt/DYBWUo=
# SIG # End signature block
