$scriptVersion = "20240808"


function ForceErr
{
    Stop-Transcript
    Rename-Item -Path $LogFile -NewName $LogErr -Force
    
    if ((Test-Path $LogFile))
    {
        Remove-Item -Path $LogFile -Force
    }

    $intunelogerr = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $Logerr.Split("\")[-1] + ".log"
    Copy-Item $Logerr $intunelogerr -Force -ErrorAction SilentlyContinue
    

    exit 13    
}

function CreateDir ($param1)
{
    try
    {
        if (-not (Test-Path $param1))
        {
            Mkdir $param1
        }
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr
    }
   
}

function DelFile ($param1)
{
    try
    {
        if ((Test-Path $param1))
        {
            Remove-Item -Path $param1 -Force
        }
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr
    }
   
}

function AutoPilot ($param1,$param2)
{
    try
    {
       $msg = $param1 + " " + $param2
       Out-File -FilePath $LogAuto -InputObject $msg -Append -Force
    }
    catch
    {
        Write-host "$Error[0]"
        ForceErr
    }
   
}

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITECTURE" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
        Exit $lastexitcode
    }
}


# Start logging
$LogAuto = "C:\Windows\Temp\Logs\AutoPilot\Acrobat.log"
$DirAuto = "C:\Windows\Temp\Logs\AutoPilot"
$LogFile = "C:\Windows\Temp\Logs\Acrobat\PS_Acrobat.log"
$LogErr = "C:\Windows\Temp\Logs\Acrobat\PS_Acrobat.nok"
$LogDir = "C:\Windows\Temp\Logs\Acrobat"
$tempDirectory = "C:\Windows\Temp\Acrobat"


CreateDir $LogDir
CreateDir $DirAuto
CreateDir $tempDirectory

DelFile $LogFile
DelFile $LogErr

Start-Transcript $LogFile
Write-Host "Begin"
Write-Host $scriptVersion


$now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
AutoPilot "Begin" $now

#$DebugPreference = 'Continue'
#$VerbosePreference = 'Continue'
#$InformationPreference = 'Continue'

try
{

    # Copy the Reg files
    Copy-Item ".\files\*" $tempDirectory -Force -Recurse  

    $files = Get-ChildItem -Path $tempDirectory

    foreach ($item in $files)
    {
        if (($item.FullName.ToUpper()).contains(".EXE") -eq $true)
        {
            $arg = "/sAll /rs /rps /sl 1033,1046 /l"
            
            $run = Start-Process -FilePath $item.FullName -ArgumentList $arg -Wait -PassThru
            
            if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010))
            {    
                Write-host "$Error[0]"
                ForceErr
            }   
        }
        
        if ((($item.FullName.ToUpper()).contains(".MSP") -eq $true) -or (($item.FullName.ToUpper()).contains(".MSI") -eq $true))
        {
            $arg = "/quiet /norestart /l*v " + $LogDir + "\" + $item.Name + ".log"
            
            $run = Start-Process -FilePath $item.FullName -ArgumentList $arg -Wait -PassThru

            if (($run.ExitCode -ne 0) -and ($run.ExitCode -ne 3010))
            {    
                Write-host "$Error[0]"
                ForceErr
            }   

        }
        
    }

    if ((Test-Path "c:\users\public\desktop\Acrobat Reader DC.lnk"))
    {
        Remove-Item -Path "c:\users\public\desktop\Acrobat Reader DC.lnk" -Force
    }

    
    if ((Test-Path -Path $TempDirectory))
    {
        Remove-Item -Path $TempDirectory -Force -Recurse
    }

    $now = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
    AutoPilot "End  " $now
    $intunelog = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension-" + $LogFile.Split("\")[-1]
    Copy-Item $LogFile $intunelog -Force -ErrorAction SilentlyContinue
    Stop-Transcript
}
catch 
{
    Write-host "$Error[0]"
    ForceErr
}

# SIG # Begin signature block
# MIImSQYJKoZIhvcNAQcCoIImOjCCJjYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUk0bRtaGWbZ6tc834MIkV7uAe
# n0yggiCHMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
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
# AwIBAgITIAACoD1dpqkXbsElQwABAAKgPTANBgkqhkiG9w0BAQsFADBQMRMwEQYK
# CZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPyLGQBGRYHYmNwY29ycDEgMB4GA1UE
# AxMXQkNQIEdyb3VwIElzc3VpbmcgQ0EgMDEwHhcNMjIwOTE2MDg1MjE3WhcNMjQw
# OTE1MDg1MjE3WjBUMQswCQYDVQQGEwJQVDEPMA0GA1UEBxMGTGlzYm9hMRcwFQYD
# VQQKEw5NaWxsZW5uaXVtIEJDUDEbMBkGA1UEAwwSRW5kcG9pbnRTV19TaWduaW5n
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxs+2qkgbf4hV4v+mSivj
# a3DGRaMTn/wEOQS046pgV6fELo6GKSF6fougchNgcXrbue1FxGFjairS8SMdvJFG
# 7rOfZuH69X1jA766zuvFUDCwite10tSGNDvKxHISH8M0Zh6uplbyBl1r+FPV1uCF
# ey1vHyDvpxin+4AMZaep8uajn+jDydZ40tfXHyZWL1EG2M8mXbI3zI8XCG0xvuqs
# ZEG8h9MvskwjlY2KGmIg0F2Wls0MGpYjEudjjvnCG1a+f1bX9OS4My6ACbsFU9XP
# J8+4xsE1JFZX7lQn3KivlGhhmnSUmGTgMmjeqAFGAaULzX67ovVdPPaPA2/hbgwx
# tQIDAQABo4IDQDCCAzwwPQYJKwYBBAGCNxUHBDAwLgYmKwYBBAGCNxUIg63yDoKd
# unaRhSOF47xxhuXJE4FBhODFGIHI4CoCAWQCAQswEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwCwYDVR0PBAQDAgeAME0GA1UdIARGMEQwQgYKKwYBBAGBgiQBAzA0MDIGCCsG
# AQUFBwIBFiZodHRwOi8vcGtpLmJjcC5wdC9kb2MvR3J1cG9CQ1BDUDAyLnBkZjAb
# BgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTQhCBTzAh6J5Xn
# VUEpIJYfa/WI/TAfBgNVHSMEGDAWgBQJ3og3Fr8xWygusRL3v/SLEMMFcjCCARUG
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
# YXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQADggEBAD5Y
# 79H2arWH/NOwWCwx31658VyhOepjognQd907EBtkgmhwKjHe4aQbh6o1t0BoBGmx
# zvEJTta+YLwzZPUV+140CjTHItIAvGSY1h4Na2Xxiv31cbdRl8vt6mvHDEJKT62W
# WFTvrSvtdgBF5rGzutQV+3PZFC8Cnp473kI+wJjgXimbTomFLrmqlYj4OGsLG9Ok
# nT9vzBhCNxZSqdviUZ6ZhzzQ0brI27DiaP7WGLlFgINSxGxIR7r6mxomhc4a/BI4
# +qaluJV9u52hTbrXL4/h4ufGi+2OdAfWDSmuFLsSie7DYfyEOfi0O93jycXX3LYS
# g9R7+25NQt5n8Y3OyPAwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0G
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
# MIIGwjCCBKqgAwIBAgIQBUSv85SdCDmmv9s/X+VhFjANBgkqhkiG9w0BAQsFADBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5n
# IENBMB4XDTIzMDcxNDAwMDAwMFoXDTM0MTAxMzIzNTk1OVowSDELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSAwHgYDVQQDExdEaWdpQ2VydCBU
# aW1lc3RhbXAgMjAyMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKNT
# RYcdg45brD5UsyPgz5/X5dLnXaEOCdwvSKOXejsqnGfcYhVYwamTEafNqrJq3RAp
# ih5iY2nTWJw1cb86l+uUUI8cIOrHmjsvlmbjaedp/lvD1isgHMGXlLSlUIHyz8sH
# pjBoyoNC2vx/CSSUpIIa2mq62DvKXd4ZGIX7ReoNYWyd/nFexAaaPPDFLnkPG2ZS
# 48jWPl/aQ9OE9dDH9kgtXkV1lnX+3RChG4PBuOZSlbVH13gpOWvgeFmX40QrStWV
# zu8IF+qCZE3/I+PKhu60pCFkcOvV5aDaY7Mu6QXuqvYk9R28mxyyt1/f8O52fTGZ
# ZUdVnUokL6wrl76f5P17cz4y7lI0+9S769SgLDSb495uZBkHNwGRDxy1Uc2qTGaD
# iGhiu7xBG3gZbeTZD+BYQfvYsSzhUa+0rRUGFOpiCBPTaR58ZE2dD9/O0V6MqqtQ
# FcmzyrzXxDtoRKOlO0L9c33u3Qr/eTQQfqZcClhMAD6FaXXHg2TWdc2PEnZWpST6
# 18RrIbroHzSYLzrqawGw9/sqhux7UjipmAmhcbJsca8+uG+W1eEQE/5hRwqM/vC2
# x9XH3mwk8L9CgsqgcT2ckpMEtGlwJw1Pt7U20clfCKRwo+wK8REuZODLIivK8SgT
# IUlRfgZm0zu++uuRONhRB8qUt+JQofM604qDy0B7AgMBAAGjggGLMIIBhzAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAU
# uhbZbU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFKW27xPn783QZKHVVqllMaPe
# 1eNJMFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmww
# gZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAIEa1t6gqbWYF7xwjU+KPGic2CX/yyzkzepd
# IpLsjCICqbjPgKjZ5+PF7SaCinEvGN1Ott5s1+FgnCvt7T1IjrhrunxdvcJhN2hJ
# d6PrkKoS1yeF844ektrCQDifXcigLiV4JZ0qBXqEKZi2V3mP2yZWK7Dzp703DNiY
# dk9WuVLCtp04qYHnbUFcjGnRuSvExnvPnPp44pMadqJpddNQ5EQSviANnqlE0Pjl
# SXcIWiHFtM+YlRpUurm8wWkZus8W8oM3NG6wQSbd3lqXTzON1I13fXVFoaVYJmoD
# Rd7ZULVQjK9WvUzF4UbFKNOt50MAcN7MmJ4ZiQPq1JE3701S88lgIcRWR+3aEUuM
# MsOI5ljitts++V+wQtaP4xeR0arAVeOGv6wnLEHQmjNKqDbUuXKWfpd5OEhfysLc
# PTLfddY2Z1qJ+Panx+VPNTwAvb6cKmx5AdzaROY63jg7B145WPR8czFVoIARyxQM
# fq68/qTreWWqaNYiyjvrmoI1VygWy2nyMpqy0tg6uLFGhmu6F/3Ed2wVbK6rr3M6
# 6ElGt9V/zLY4wNjsHPW2obhDLN9OTH0eaHDAdwrUAuBcYLso/zjlUlrWrBciI070
# 7NMX+1Br/wd3H3GXREHJuEbTbDJ8WC9nR2XlG3O2mflrLAZG70Ee8PBf4NvZrZCA
# RK+AEEGKMIIHAzCCBeugAwIBAgIKYQYhBwABAAAAGzANBgkqhkiG9w0BAQsFADBK
# MRMwEQYKCZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPyLGQBGRYHYmNwY29ycDEa
# MBgGA1UEAxMRR3J1cG8gQkNQIFJvb3QgQ0EwHhcNMjEwNjA3MTg1NDAyWhcNMjkw
# NjA3MTkwNDAyWjBQMRMwEQYKCZImiZPyLGQBGRYDbmV0MRcwFQYKCZImiZPyLGQB
# GRYHYmNwY29ycDEgMB4GA1UEAxMXQkNQIEdyb3VwIElzc3VpbmcgQ0EgMDEwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCzIbm7obAwnuexsgwr/qMKPJNq
# R6GDgTHqFoAVMKnga1+tYGE94a1Pz6GhAXJQaRLEE16axSA5NIdZFHuQ6hRmfUjK
# WXnRo+vPSTrI3Bb75zmtePVB0ALqoWdJOtGUlRRugf7S8zEep7T39LZN8LDLLDRQ
# fBVm6dp63KAVeaHcefYGodl1btbkdCfv86aPZXqMthgXUtw9DnXjO3WDeEZLJ2qC
# BAyn7I2oCT6yBvQ7Yggg8a+4QI4QPSL4ey9AaC4tZzaO2/atO7OyerwH0GjRaS5k
# NNj9p6elDnpyoSEOeseJPL7zRuqVBtgfSbmBsvrj9KXwaxFOEJLIufakoBUlAgMB
# AAGjggPjMIID3zAQBgkrBgEEAYI3FQEEAwIBATAjBgkrBgEEAYI3FQIEFgQUE/ks
# CUZwIFVxJHeErn6IivmHREswHQYDVR0OBBYEFAneiDcWvzFbKC6xEve/9IsQwwVy
# MIIBHAYDVR0gBIIBEzCCAQ8wQQYKKwYBBAGBgiQBATAzMDEGCCsGAQUFBwIBFiVo
# dHRwOi8vcGtpLmJjcC5wdC9kb2MvR3J1cG9CQ1BDUFMucGRmMEIGCisGAQQBgYIk
# AQIwNDAyBggrBgEFBQcCARYmaHR0cDovL3BraS5iY3AucHQvZG9jL0dydXBvQkNQ
# Q1AwMS5wZGYwQgYKKwYBBAGBgiQBAzA0MDIGCCsGAQUFBwIBFiZodHRwOi8vcGtp
# LmJjcC5wdC9kb2MvR3J1cG9CQ1BDUDAyLnBkZjBCBgorBgEEAYGCJAEEMDQwMgYI
# KwYBBQUHAgEWJmh0dHA6Ly9wa2kuYmNwLnB0L2RvYy9HcnVwb0JDUENQMDMucGRm
# MBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMB
# Af8EBTADAQH/MB8GA1UdIwQYMBaAFJVSOEGWkT6bjf1rH8NnO71IFVOWMIIBBAYD
# VR0fBIH8MIH5MIH2oIHzoIHwhihodHRwOi8vcGtpLmJjcC5wdC9jcmwvR3J1cG9C
# Q1BSb290Q0EuY3JshoHDbGRhcDovLy9DTj1HcnVwbyUyMEJDUCUyMFJvb3QlMjBD
# QSxDTj1TRVRQU0ZJUkNBMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
# Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9YmNwY29ycCxEQz1u
# ZXQ/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNS
# TERpc3RyaWJ1dGlvblBvaW50MIIBAwYIKwYBBQUHAQEEgfYwgfMwOAYIKwYBBQUH
# MAKGLGh0dHA6Ly9wa2kuYmNwLnB0L2NlcnQvR3J1cG9CQ1BSb290Q0EoMSkuY3J0
# MIG2BggrBgEFBQcwAoaBqWxkYXA6Ly8vQ049R3J1cG8lMjBCQ1AlMjBSb290JTIw
# Q0EsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9YmNwY29ycCxEQz1uZXQ/Y0FDZXJ0aWZpY2F0
# ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZI
# hvcNAQELBQADggEBACOxW9OL7kX4GBNkExCmNJDjJIBIGIv4y/vdqgVqLLEEXHTP
# 2jFytvWfvXKzbrsLyVo1aE87Yb2ux8SdIytIoxJRxDu7CgbISPR0P4zUA3zxebvc
# VtyymstYLsPGmtzR7RaibV7xojHwhyy+T3PId7KE554iuAMWV7V1yBLYa9CM2Du6
# V2wPcpIms2wcZmioP55WidK/Boo9ZDqbe2L6kfL0KaKzJNWs5eeaijNyxhivXpJa
# 44Goata8th4K4vKUYT6qNSo1JS3F5onupInHEiGNbgW3aNUuBldz7FWlZXy907V1
# 3b+gqUn58YndBwyPMlBoV6Z8PQ1zM5sUTH7k8aUxggUsMIIFKAIBATBnMFAxEzAR
# BgoJkiaJk/IsZAEZFgNuZXQxFzAVBgoJkiaJk/IsZAEZFgdiY3Bjb3JwMSAwHgYD
# VQQDExdCQ1AgR3JvdXAgSXNzdWluZyBDQSAwMQITIAACoD1dpqkXbsElQwABAAKg
# PTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
# FTAjBgkqhkiG9w0BCQQxFgQU27Xr0Gf+DUYbrzGNBVK/jZpIBR4wDQYJKoZIhvcN
# AQEBBQAEggEApl8aNzBA5/9zIm+j/XfV1i2rwXDXZlpkYVc/XyjV2roxlJeRXbl5
# b+YooDZroe35IE6sVV+zTh58oy0EvaKVmpm75ZinP23wKfG/7uqTS/CFHt1ND3Xj
# B1L5JiKVXBZyNNB+yZG4eKtMVzLjmBqHQ2HK20fsJEsgx78clfTMSDtwkrKyatK3
# gyE/jc1020Q6roFYBJHsOYUR5zJSXPsLGuhOyuDeIPBtxfaMZNqFV9IUjnpv/jp2
# 3i7IrWUOcdoF7UO4Z2UKyzRyhjoMeqGzqh2SPnypmbon85m92IBW2Cq3wOOwJaJW
# y3OuavNn2+XPknWU0VEteit3YRHHEY4mdaGCAyAwggMcBgkqhkiG9w0BCQYxggMN
# MIIDCQIBATB3MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5j
# LjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBU
# aW1lU3RhbXBpbmcgQ0ECEAVEr/OUnQg5pr/bP1/lYRYwDQYJYIZIAWUDBAIBBQCg
# aTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNDA4
# MDgxMjAyMzRaMC8GCSqGSIb3DQEJBDEiBCBR7rzd795oEnAgKsokIFk85SARMXP+
# /EskIDQkC6nX/DANBgkqhkiG9w0BAQEFAASCAgACJgX+AlZGQ6jbF9rrFM5yu6XS
# m5J0DUyfNBT0lZhBenZe8CtIfRWmkXL3mf6x2G5V8k4Mi5j914FDasywdZ8NuKS0
# uBCucg8zNZsrTxyFNcPUF2OVEf710mNDL3dP1MuiQkoQmS4LqrDm+D0D11/zSj0M
# HKqK/IUeSj1PozUbHjUX9m++2JbmxDFrKxnr1eKGmxE8/CwdHJVFk86pYxbrMbdc
# /2mTwNKh4nzu4MUp3LVSQI18RP1MQ9wPZAWIRT4lodp3nVMXtQG/cV1xKDEm3ssH
# 1tkAWLpR5uIwqvH9be3FzE930o8Get9m2xCyy9U6GR9CFvPXqZVVp9/SQ313WU3M
# A2kvjUfA4AcSu9rEgyO9PEjHbBfSWW4ay0nHns9BTY9cpdpNXs3YUKB6RO1hm6NI
# WevgNoYDNO9wA2v4mPU4IdF4eq1EiVPyr3GWNMjdaQUzqoLLunu47s5eyhEbCbwL
# Ko6W8PGBQP863+r1MPOZc0HBwvDzyTh22mzpQP86fe8hXN2SfYzb3qIntFmKSsEE
# Ij+mxaYUQkoNpxX5sz5oinEb9Y7G4MUW8TMA/cmVSxGayxIn+Ol4h4s+DERlY2My
# M21F856IA+3Jz//UItE8F2eRrBpsrJjZ624pcxspbV4PsUXEQv+pfimCynSvRfeQ
# 7l1JS1DmZkjx4NHLNw==
# SIG # End signature block
