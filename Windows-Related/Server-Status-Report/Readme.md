# Server-Status-Report

## Overview

### Purpose
This script will fetch the server information remotly.

## Requirements (required)
Powershell, WMI and access to the server.
Make sure you are running this script with the account for which you have access to the target server.
### Module
Used PSWriteHTML  0.0.71
Used Dashimo 0.0.22

## Configuration (required)
Sneding email notification - Update SMTP server details as per your configuration.
```Powershell 
$smtpServer = "SMTP" # SMTP server
$smtpFrom = "FromAddress"
$smtpTo = "TOAddress"
```

## Examples

## Notes

