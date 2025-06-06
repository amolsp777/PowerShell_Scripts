# 🛠️ Remote Windows C: Drive Extension Script via PowerShell + DiskPart

This PowerShell script automates the expansion of the C: drive on a remote Windows server using `diskpart`. It avoids `Get-PartitionSupportedSize` and `Resize-Partition`, making it faster and more reliable on heavily loaded systems or where PowerShell remoting is slow or blocked.

---

## ✅ Features

- Automatically generates a `diskpart` script remotely.
- Runs expansion on C: drive without user interaction.
- Uses `Invoke-Command` with `try/catch` for robust error handling.
- Fully in PowerShell – no external files required.
- Optional CSV logging supported.

---

## 🔧 Requirements

- PowerShell Remoting enabled (WinRM) on the target server.
- Admin privileges on the remote machine.
- C: volume must be the last volume on the disk (standard setup).
- Sufficient unallocated space on the disk.

---

## 🧩 Script Overview

```powershell
$vmName = "vm1"
$diskpartScript = @"
select volume C
extend
exit
"@

try {
    Invoke-Command -ComputerName $vmName -ScriptBlock {
        param($scriptContent)
        try {
            $scriptPath = "C:\Temp\extend_c_drive.txt"
            if (-not (Test-Path 'C:\Temp')) {
                New-Item -Path 'C:\Temp' -ItemType Directory -Force | Out-Null
            }
            Set-Content -Path $scriptPath -Value $scriptContent -Encoding ASCII
            $output = diskpart /s $scriptPath
            Write-Output "✅ DiskPart executed successfully:`n$output"
        } catch {
            Write-Error "❌ Error during remote execution: $_"
        }
    } -ArgumentList $diskpartScript -ErrorAction Stop
}
catch {
    Write-Error "❌ Failed to run Invoke-Command on $vmName: $_"
}
```
## 📄 Optional Logging

``` powershell
$logEntry = [PSCustomObject]@{
    VMName     = $vmName
    Status     = "Success"
    Timestamp  = Get-Date
    Output     = $output
}
$logEntry | Export-Csv "C:\Logs\DiskExtendLog.csv" -Append -NoTypeInformation
```
## 🚨 Warnings
- Make sure unallocated space exists before using extend.
- If the disk has multiple partitions, diskpart may not behave as expected.
- Test this on a staging system before applying in production.

## 📦 Author / Maintainer
This script was built for system administrators looking for a non-interactive, scriptable way to resize VM disks and partitions remotely using built-in Windows tools.