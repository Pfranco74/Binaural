function ForceErr
{
    Stop-Transcript

    
    if ((Test-Path $LogErr))
    {
        Remove-Item -Path $LogErr -Force
    }

    Rename-Item -Path $LogFile -NewName $LogErr
    
    if ((Test-Path $LogFile))
    {
        Remove-Item -Path $LogFile -Force
    }

    exit 13    
}




# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "c:\Windows\Temp\Logs\MsTeams"))
{
    Mkdir "c:\Windows\Temp\Logs\MsTeams"
}

    
if ((Test-Path $LogErr))
{
    Remove-Item -Path $LogErr -Force
}

$LogFile = "c:\Windows\Temp\Logs\MsTeams\MicrosoftTeamsNEW_Inst.log"
$LogErr = "c:\Windows\Temp\Logs\MsTeams\MicrosoftTeamsNEW_Inst.nok"
$InstTeams = $false

$LogPath = $LogFile

# Start transcript logging
Start-Transcript -Path $LogPath -Force


###########################################################
# New Teams installation
###########################################################

Write-Host "Installing new Teams"
# Get the current directory
$currentDirectory = Split-Path -Parent $PSCommandPath

# Build the path to the exe file
$exePath = Join-Path -Path $currentDirectory -ChildPath "teamsbootstrapper.exe"

# Start the exe process
$inst = (Start-Process -FilePath $exePath -ArgumentList "-p" -NoNewWindow -Wait -PassThru)

#check teams
$msteams = Get-ChildItem -Path 'C:\Program Files\WindowsApps' -Filter MSTeam*

if ($msteams -ne $null)
{
    foreach ($item in $msteams)
    {
        $today = Get-Date
        $instdate = ($item.lastwritetime).Date
        $dif = New-TimeSpan -Start $instdate -end $today

        if ($dif.Days -gt 1)
        {
            write-host "Teams not installed"
            ForceErr            
        }
        else
        {
            $InstTeams = $true
        }
    }
}
Else
{
    write-host "Teams not installed"
    ForceErr
}

if ($InstTeams -eq $false)
{
    write-host "Teams not installed"
    ForceErr

}

# Stop transcript logging
Stop-Transcript