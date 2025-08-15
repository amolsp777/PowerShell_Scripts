###############################################
# Author: Amol
# Date: Friday, August 15, 2025 1:31:15 PM
# Description:  Check C: drive details of multiple servers and their status.
###############################################

#region === Parameters ===
$ServerListFile = ($PSScriptRoot + "\servers.txt")
$Servers = Get-Content $ServerListFile
$Total = $Servers.Count
$Count = 0
#endregion

#region === Function: GetStatusCode ===
Function GetStatusCode {
    Param ([int]$StatusCode)
    switch ($StatusCode) {
        0       { "Online" }
        11001   { "Buffer Too Small" }
        11002   { "Destination Net Unreachable" }
        11003   { "Destination Host Unreachable" }
        11004   { "Destination Protocol Unreachable" }
        11005   { "Destination Port Unreachable" }
        11006   { "No Resources" }
        11007   { "Bad Option" }
        11008   { "Hardware Error" }
        11009   { "Packet Too Big" }
        11010   { "Request Timed Out" }
        11011   { "Bad Request" }
        11012   { "Bad Route" }
        11013   { "TimeToLive Expired Transit" }
        11014   { "TimeToLive Expired Reassembly" }
        11015   { "Parameter Problem" }
        11016   { "Source Quench" }
        11017   { "Option Too Big" }
        11018   { "Bad Destination" }
        11032   { "Negotiating IPSEC" }
        11050   { "General Failure" }
        default { "Failed" }
    }
}
#endregion

#region === Function: Get-HostUptime ===
Function Get-HostUptime {
    param ([string]$ComputerName)
    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
        $LastBootUpTime = $OS.LastBootUpTime
        $Time = (Get-Date) - $LastBootUpTime
        return $Time.Days
    }
    catch {
        return "N/A"
    }
}
#endregion

#region === Main Processing ===
$Results = foreach ($ComputerName in $Servers) {
    $Count++
    $Percent = ($Count / $Total) * 100
    Write-Progress -Activity "Checking Servers" `
                   -Status "Processing $ComputerName ($Count of $Total)" `
                   -PercentComplete $Percent

    #region Test Connectivity
    try {
        $PingResult = Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Stop
        $PingCode = "Online"
    }
    catch {
        try {
            $PingStatus = Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction SilentlyContinue
            if ($PingStatus.StatusCode) {
                $PingCode = GetStatusCode $PingStatus.StatusCode
            }
            else {
                $PingCode = "Unreachable"
            }
        }
        catch {
            $PingCode = "Unreachable"
        }
    }
    #endregion

    #region Collect Data
    if ($PingCode -eq "Online") {
        try {
            $Disk = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $ComputerName -Filter "DeviceID='C:'" -ErrorAction Stop
            $FreeGB = "{0:N2}" -f ($Disk.FreeSpace / 1GB)
            $TotalGB = "{0:N2}" -f ($Disk.Size / 1GB)
            $FreePercent = "{0:N0}" -f [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 0)
            $UsedGB = "{0:N2}" -f (($Disk.Size - $Disk.FreeSpace) / 1GB)
        }
        catch {
            $FreeGB = $TotalGB = $FreePercent = $UsedGB = "N/A"
        }

        $UptimeDays = Get-HostUptime -ComputerName $ComputerName
    }
    else {
        $FreeGB = $TotalGB = $FreePercent = $UsedGB = $UptimeDays = "N/A"
    }
    #endregion

    #region Output Object
    [PSCustomObject]@{
        ComputerName = $ComputerName
        Status       = $PingCode
        TotalGB      = $TotalGB
        UsedGB       = $UsedGB
        FreeGB       = $FreeGB
        FreePercent  = $FreePercent
        UptimeDays   = $UptimeDays
    }
    #endregion
}
#endregion

#region === Final Output ===
$Results | Format-Table -AutoSize
$Results | Export-Csv -Path ($PSScriptRoot + "\ServerDiskReport.csv") -NoTypeInformation
#endregion
