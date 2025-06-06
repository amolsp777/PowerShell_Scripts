###############################################
# Author: Amol Patil
# Date: 06/06/2025
# Description: Remote Windows C: Drive Extension Script via PowerShell + DiskPart Enter a description here.
###############################################

# Parameters
$vmName = "vm1"
$desiredFreePercent = 15
$vCenterServer = "myvc.mydomain.com"

$logFile = ($PSScriptRoot + "\VM_DiskExpansion_$vmName.log")
$csvPath = ($PSScriptRoot + "\VM_DiskExpansion_Report.csv")


# Function to write log entries
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp `t $message"
    Write-Host $message
}

# Function to write CSV entries
function Append-CsvLog {
    param (
        [string]$vmName,
        [decimal]$vmDiskSizeBefore,
        [decimal]$cDriveSize,
        [decimal]$freePercentBefore,
        [decimal]$vmDiskSizeAfter,
        [decimal]$freePercentAfter,
        [string]$status
    )
    $row = [PSCustomObject]@{
        VMName                 = $vmName
        VM_DiskSizeGB          = $vmDiskSizeBefore
        CDriveSizeGB           = $cDriveSize
        CFreePercentBefore     = $freePercentBefore
        ExpandedVM_DiskSizeGB  = $vmDiskSizeAfter
        CFreePercentAfter      = $freePercentAfter
        LastUpdate             = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Status                 = $status
    }
    $row | Export-Csv -Path $csvPath -Append -NoTypeInformation
}

# Ensure CSV has header
if (-not (Test-Path $csvPath)) {
    "VMName,VM_DiskSizeGB,CDriveSizeGB,CFreePercentBefore,ExpandedVM_DiskSizeGB,CFreePercentAfter,LastUpdate,Status" | Out-File -FilePath $csvPath -Encoding UTF8
}

# Start Logging
Write-Log "=== Starting disk check for $vmName ==="

# Connect to vCenter
try {
    Connect-VIServer -Server $vCenterServer -ErrorAction Stop
    Write-Log "Connected to vCenter: $vCenterServer"
} catch {
    Write-Log "ERROR: Failed to connect to vCenter. $_"
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore 0 -cDriveSize 0 -freePercentBefore 0 -vmDiskSizeAfter 0 -freePercentAfter 0 -status "Error - vCenter Connect"
    exit 1
}

# Get VM object
try {
    $vm = Get-VM -Name $vmName -ErrorAction Stop
    Write-Log "Found VM: $vmName"
} catch {
    Write-Log "ERROR: VM $vmName not found. $_"
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore 0 -cDriveSize 0 -freePercentBefore 0 -vmDiskSizeAfter 0 -freePercentAfter 0 -status "Error - VM Not Found"
    exit 1
}

# Get current disk usage inside guest
try {
    $session = New-PSSession -ComputerName $vmName -ErrorAction Stop
    $disk = Invoke-Command -Session $session -ScriptBlock {
        Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | 
        Select-Object Size, FreeSpace
    }
    Remove-PSSession $session
    Write-Log "Retrieved C: drive usage."
} catch {
    Write-Log "ERROR: Failed to retrieve disk info from $vmName. $_"
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore 0 -cDriveSize 0 -freePercentBefore 0 -vmDiskSizeAfter 0 -freePercentAfter 0 -status "Error - Disk Info"
    exit 1
}

$total = [math]::Round($disk.Size / 1GB, 2)
$free = [math]::Round($disk.FreeSpace / 1GB, 2)
$currentFreePercent = [math]::Ceiling(($free / $total) * 100)

Write-Log "C: Drive - Total: $total GB, Free: $free GB ($currentFreePercent%)"

if ($currentFreePercent -lt $desiredFreePercent) {
    $used = $total - $free
    $requiredTotal = [math]::Ceiling($used / (1 - ($desiredFreePercent / 100)))

    if ($requiredTotal -gt $total) {
        Write-Log "Expanding disk from $total GB to $requiredTotal GB..."

        try {
            $hardDisk = Get-HardDisk -VM $vm | Where-Object {$_.Name -eq "Hard disk 1"} -ErrorAction Stop
            Set-HardDisk -HardDisk $hardDisk -CapacityGB $requiredTotal -Confirm:$false -ErrorAction Stop
            Write-Log "VMware disk expanded successfully."
        } catch {
            Write-Log "ERROR: Failed to expand VMware disk. $_"
            Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freePercentBefore $currentFreePercent -vmDiskSizeAfter $total -freePercentAfter $currentFreePercent -status "Error - VMware Expansion"
            exit 1
        }

        try {
            #$creds = Get-Credential
            Write-Log "Expanding partition inside guest OS..."

            $diskpartScript = @"
select volume C
extend
exit
"@

# Copy the script to the remote server
try {
    # Invoke command on remote server
    Invoke-Command -ComputerName $vmName -ScriptBlock {
        param($scriptContent)
        try {
            $scriptPath = "C:\Temp\extend_c_drive.txt"

            if (-not (Test-Path 'C:\Temp')) {
                New-Item -Path 'C:\Temp' -ItemType Directory -Force | Out-Null
            }

            Set-Content -Path $scriptPath -Value $scriptContent -Encoding ASCII

            $output = diskpart /s $scriptPath
            Write-Output "✅ DiskPart executed successfully`n$output"
        } catch {
            Write-Error "❌ Error during remote execution $_"
        }
    } -ArgumentList $diskpartScript -ErrorAction Stop
}
catch {
    Write-Error "❌ Failed to run Invoke-Command on $vmName $_"
}

<# Invoke-Command -ComputerName $vmName -ScriptBlock {
     param($scriptContent)
     $scriptPath = "C:\Temp\extend_c_drive.txt"
     if (-not (Test-Path 'C:\Temp')) { New-Item -Path 'C:\Temp' -ItemType Directory }
     Set-Content -Path $scriptPath -Value $scriptContent
     diskpart /s $scriptPath
    } -ArgumentList $diskpartScript
     #>
<#             Invoke-Command -ComputerName $vmName -ScriptBlock {
                $size = (Get-PartitionSupportedSize -DriveLetter C -Verbose ).SizeMax 
                Resize-Partition -DriveLetter C -Size $size -Confirm:$false -Verbose
            }  -ErrorAction Stop -Verbose #>
            Write-Log "Partition resized inside guest successfully."
        } catch {
            Write-Log "ERROR: Failed to resize guest OS partition. $_"
            Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freePercentBefore $currentFreePercent -vmDiskSizeAfter $requiredTotal -freePercentAfter $currentFreePercent -status "Error - Partition Resize"
            exit 1
        }

        try {
            $session = New-PSSession -ComputerName $vmName -ErrorAction Stop
            $diskUpdated = Invoke-Command -Session $session -ScriptBlock {
                Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | 
                Select-Object Size, FreeSpace
            }
            Remove-PSSession $session

            $newTotal = [math]::Round($diskUpdated.Size / 1GB, 2)
            $newFree = [math]::Round($diskUpdated.FreeSpace / 1GB, 2)
            $newFreePercent = [math]::Round(($newFree / $newTotal) * 100, 2)

            Write-Log "✅ New C: Drive Stats - Total: $newTotal GB, Free: $newFree GB ($newFreePercent%)"

            Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freePercentBefore $currentFreePercent -vmDiskSizeAfter $newTotal -freePercentAfter $newFreePercent -status "Expanded"
        } catch {
            Write-Log "ERROR: Could not retrieve updated disk info. $_"
            Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freePercentBefore $currentFreePercent -vmDiskSizeAfter $requiredTotal -freePercentAfter 0 -status "Error - Final Check"
        }

        Write-Log "✅ Disk and partition expansion complete for $vmName."
    } else {
        Write-Log "Calculated required size is not greater than current size. No action taken."
        Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freePercentBefore $currentFreePercent -vmDiskSizeAfter $total -freePercentAfter $currentFreePercent -status "No Action"
    }
} else {
    Write-Log "No expansion needed. Free space is sufficient."
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freePercentBefore $currentFreePercent -vmDiskSizeAfter $total -freePercentAfter $currentFreePercent -status "No Action"
}

Write-Log "=== Script completed for $vmName ==="