# Daily System Checks for IT System Administrators

This repository contains useful commands and scripts for daily system checks and tasks for IT system administrators or system engineers. These scripts cover both Linux and Windows environments.

## Windows Admin
### Windows PowerShell Commands

#### Check System Uptime
> Check LastBootUpTime
```powershell
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
```
> Check Last_5_Reboots
```powershell
$servers = $env:COMPUTERNAME
# To get the last 5 reboot date/time of the windows server.

Foreach ($server in $servers){
get-eventlog -ComputerName $server system | where-object {$_.eventid -eq 6006} | select MachineName,EntryType,EventID,Message,TimeWritten,UserName -first 5 | FT
}
```

#### Check Disk Usage
```powershell
Get-PSDrive -PSProvider FileSystem
```
> Get-Volume Details
```powershell
Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } `
| Select-Object @{Name = 'ComputerName'; Expression = { $env:COMPUTERNAME }}, DriveLetter, FileSystemLabel, @{Name = 'SizeRemaining'; Expression = { "{0:N2} Gb" -f ($_.SizeRemaining / 1Gb)}}, @{Name = 'TotalSize'; Expression = { "{0:N2} Gb" -f ($_.Size / 1Gb) }}, @{Name='% Free'; Expression={"{0:P}" -f ($_.SizeRemaining / $_.Size)}} `
| Sort-Object DriveLetter
```
> Get Disk label, capacity & block size
```powershell
#-------------------------------------------------------------------@
#           Get Disk label, capacity & block size
#-------------------------------------------------------------------@
#region Get Disk lable, capacity & block size
Get-WmiObject -Class Win32_Volume |
Where-Object { $_.Label -ne 'System Reserved' -and $_.DriveType -eq 3 } |
Select-Object SystemName, DriveLetter, Label, BlockSize,
@{ Name = "Capacity(GB)"; Expression = { [math]::Round($_.Capacity / 1GB, 2) } },
@{ Name = "FreeSpace(GB)"; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) } } |
Sort-Object DriveLetter |
Format-Table -AutoSize
#endregion Get Disk lable, capacity & block size
```


#### Check Memory Usage
Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory

#### Check Running Processes
Get-Process

#### Check Event Logs
Get-EventLog -LogName System -Newest 10

### Additional PowerShell Commands
#### Check Network Configuration
Get-NetIPConfiguration

#### Check Installed Software
Get-WmiObject -Class Win32_Product

#### Check System Services
Get-Service

#### Check System Updates
Get-WindowsUpdateLog

#### Check System Performance
Get-Counter -Counter "\Processor(_Total)\% Processor Time"

### Command Prompt (CMD) Commands
#### Check IP Configuration
> ipconfig /all

#### Trace Network Route
> tracert <hostname>

#### Check Installed Drivers
> driverquery

#### Check System Information
> systeminfo

#### Check Disk for Errors
> chkdsk /f



#### Amol
**Amol**
