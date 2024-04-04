# Server-Status-Report

## Overview
Windows Server Status report script will fetch the Windows server information remotely.<br>
Information gathered from WMI
### Purpose
Fetch the Windows server information remotely.

## Requirements (required)
Powershell, WMI, and access to the server.
Make sure you are running this script with the account for which you have access to the target server.
### Module
Used PSWriteHTML  0.0.71
```powershell
Install-Module -Name PSWriteHTML -AllowClobber -Force
```
Used Dashimo 0.0.22
```powershell
Install-Module -Name Dashimo -AllowClobber -Force
```
Module Author - [Evotec](https://github.com/EvotecIT/PSWriteHTML)

### Script

Below code will check If the machine is pinging and it will the take TTL value from machine's Ping response and validate Is its Virtual Or Physical using WMI Class ```Get-WmiObject -Class Win32_ComputerSystem``` and get the Manufacturer value.
```powershell
	If (($pingStatus.StatusCode -eq 0) -and ($TTLOS -ge 100 -and $TTLOS -le 128 -or $TTLOS -le 0)) {
		#Add-WriteHost "[$ADcompName]- Checking OS & Hotfix Details"
		$CPUInfoCount = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName
		If (($CPUInfoCount.Manufacturer -like "VM*") -or ($CPUInfoCount.Manufacturer -like "Microsoft*")) {
			$phyvm = "Virtual"
		}
		else { $phyvm = "Physical" }
```


## Configuration (required)
Sending email notification - Update SMTP server details as per your configuration.
```Powershell 
$smtpServer = "SMTP" # SMTP server
$smtpFrom = "FromAddress"
$smtpTo = "TOAddress"
```

## Examples

## Notes

