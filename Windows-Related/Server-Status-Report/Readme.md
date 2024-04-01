# Server-Status-Report

## Overview

### Purpose
This script will fetch the server information remotely.

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

## Configuration (required)
Sending email notification - Update SMTP server details as per your configuration.
```Powershell 
$smtpServer = "SMTP" # SMTP server
$smtpFrom = "FromAddress"
$smtpTo = "TOAddress"
```

## Examples

## Notes

