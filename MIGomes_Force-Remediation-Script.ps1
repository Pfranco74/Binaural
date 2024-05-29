Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\InventorySetting" -Name LastFullSyncTimeUtc -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32AppSettings" -Name LastFullResultReportTimeUTC -Force -ErrorAction SilentlyContinue
$Items = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Scripts\Execution" -Recurse
foreach ($item in $items)
{
    $Value = $item.GetValue("LastExecution")
    if ($null -ne $Value)
    {
        $Path = $item.PSPath
        Remove-ItemProperty -Path $Path -Name LastExecution -Force -ErrorAction SilentlyContinue
    }
}
$item = Get-Item -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Scripts\Reports"
$subKey = $item.GetSubKeyNames()
Remove-ItemProperty -Path "$($item.PSPath)\$($subKey[0])" -Name LastFullReportTimeUTC -Force -ErrorAction SilentlyContinue
 
# !! Don't do this during Autopilot !! 
Restart-Service -Name IntuneManagementExtension -Force