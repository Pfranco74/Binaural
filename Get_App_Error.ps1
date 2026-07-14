$scriptversion = '20241106'
cls
$AllApp = $null
$CatchError = $null

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


$AllApp = AppstobeInstall $JoinedFile 
$readfile = Get-Content -Path $JoinedFile


foreach ($item in $readfile)
{

    $erro = "NewValue"":""Error"
    if (($item -like "*$erro*") -and ($CatchError -ne $true))
    {
        $foundError = $item.Substring(69,36)
        foreach ($item in $AllApp)
        {
            if ($item -like "*$foundError*")
            {
                $ID = $item.Split(";")[0]
                $Name = $item.Split(";")[-1]
                write-host "Found error on App" -ForegroundColor Red
                write-host "ID   : $id"
                write-host "Name : $name"
                $CatchError = $True
            }
        }

    }
}



# SIG # Begin signature block
# MIIfPAYJKoZIhvcNAQcCoIIfLTCCHykCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUKkg5uvS9LaqNTw/SpqkJKpox
# zOugghl6MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFG4UPZ4UiKsP+6ct
# booQ15wODcS5MA0GCSqGSIb3DQEBAQUABIIBAIcSHYQVTnDebN1pYm+6sExekKvR
# wYUGMPhSntCpsRxG1ELWgUYoqKH0zyXnnK50ZAFFlwEEhxarH0n4gG6RnjiDKcDM
# 6VWn3epGddB0MZVGwE6AQWkVcyFE2DR3iSwcG06b7/4xMqfaYhrM1lm06GCNFDV1
# ODmf7UCoOryUcijYxweYOPyS1/7URsW74ACuRFWerjG8mu8SCgpQqyE/IqojceKp
# 9piI+uTXFfYXD+cJwav+M86BVyo54hz2ErqVxl8KZvb74uir8tCtsxesVFIrSz5k
# k2qvDYYo1gzxX7J294UdK8HKV0P3kP98v28UmIxi+63GXp4vBpRld920M1ahggMg
# MIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUG
# A1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQg
# RzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/lYfG+ekE
# 4zMEMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAc
# BgkqhkiG9w0BCQUxDxcNMjQxMTA3MTkxNjMwWjAvBgkqhkiG9w0BCQQxIgQgkDqN
# LqrzWJKRdQPH13yqWFcDmRLkfMZPLZGNv6JuUJMwDQYJKoZIhvcNAQEBBQAEggIA
# DECj0IwOae/zuqnQjjO8JlKVYikKsMAZ2JVCFEBObAlt/+Db3l6cem8pgjZR2m/K
# xYbI5GMliuAo8PnUuJlPHa36kvBEAXjkw9zdDRhPkgQkcz10WeduHD/PgmJwdhte
# T1A5FCjHCBBUEiFLm92DRM/IlT+kvdlswBx4hk1z6UjA/UV2aDMkUNn/B71g1aSE
# EYvpMgskWKcZ4y0wQcnu1bjcNdfghrG8uTnXD5qGQrWPaQEhAvfPU1oAJowk2ahq
# fkutCIf42+HyvebvjytauIGJI18ZdutFYGdnS8/eGxG7bchNXbQ1WciIhYJLoCSx
# mdhrB5IwTBUQLjX28IDV/HcojUZcvverAVBqdYZcBrCNiRy0I41kE132U2NpH+67
# 1OHVpkqRpfK2y+mcFkyEp1V0Kp6THx32My9HSqY+XTH17UYRWpOufoUYT2fUd/dA
# 5WZyPaTClQYejcfhnEGraI4I5OxOspED6ZrB7qUtn8kmzNMstB7tziINo5dvkJOp
# nTIop9WxJddfvOnQkH6sHZGVQjIoF8c8wNzBOaUclmORIcSCJC11JYkbkrGKNnDj
# HG3U73BqeEDcCrs3i8Vq73QNfe6PBW65IR5zEzI7Qwn41maGUvFhqgDysx3g8Uuw
# oF+GipjXnFUWdjTxf+v+phl8Vqg5DfTficwufHB3Hl4=
# SIG # End signature block
