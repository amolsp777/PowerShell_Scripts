###############################################
# Author: Amol
# Date: '09/15/2025'
# Description: The VM Disk Expansion Script v4 is a PowerShell automation tool designed to automatically expand 
#               VMware virtual machine disks and Windows partitions to ensure a specified amount of free space is available on the C: drive. 
#  
###############################################

# Parameters
$vmName = "VMNAME"
$desiredFreeSpaceGB = 20  # Fixed free space requirement in GB
$vCenterServer = "VC-FQDN"

$logFile = ($PSScriptRoot + "\VM_DiskExpansion_$vmName.log")
$csvPath = ($PSScriptRoot + "\VM_DiskExpansion_Report_v4.csv")

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
        [decimal]$freeSpaceBefore,
        [decimal]$vmDiskSizeAfter,
        [decimal]$freeSpaceAfter,
        [string]$status
    )
    $row = [PSCustomObject]@{
        VMName                 = $vmName
        VM_DiskSizeGB          = $vmDiskSizeBefore
        CDriveSizeGB           = $cDriveSize
        CFreeSpaceGBBefore     = $freeSpaceBefore
        ExpandedVM_DiskSizeGB  = $vmDiskSizeAfter
        CFreeSpaceGBAfter      = $freeSpaceAfter
        LastUpdate             = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Status                 = $status
    }
    $row | Export-Csv -Path $csvPath -Append -NoTypeInformation
}

# Function to refresh disk information
function Refresh-DiskInfo {
    param ([string]$computerName)
    
    try {
        Write-Log "Refreshing disk information on $computerName..."
        $refreshResult = Invoke-Command -ComputerName $computerName -ScriptBlock {
            try {
                # Method 1: PowerShell refresh
                $disks = Get-Disk
                foreach ($disk in $disks) {
                    $disk | Update-Disk -ErrorAction SilentlyContinue
                }
                
                $partitions = Get-Partition
                foreach ($partition in $partitions) {
                    $partition | Update-Partition -ErrorAction SilentlyContinue
                }
                
                Write-Output "PowerShell disk refresh completed"
                
                # Method 2: Use diskpart to rescan disks
                try {
                    $diskpartScript = @"
rescan
exit
"@
                    $tempDir = "C:\Temp"
                    if (-not (Test-Path $tempDir)) {
                        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
                    }
                    
                    $scriptPath = "$tempDir\rescan_disks.txt"
                    Set-Content -Path $scriptPath -Value $diskpartScript -Encoding ASCII
                    
                    $diskpartOutput = & diskpart /s $scriptPath 2>&1
                    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
                    
                    Write-Output "Diskpart rescan completed: $($diskpartOutput -join '; ')"
                    
                    # Wait a moment for the rescan to take effect
                    Start-Sleep -Seconds 3
                    
                } catch {
                    Write-Output "Diskpart rescan failed: $_"
                }
                
                return $true
            } catch {
                Write-Output "Disk refresh failed: $_"
                return $false
            }
        } -ErrorAction SilentlyContinue
        
        if ($refreshResult -eq $true) {
            Write-Log "✅ Disk information refreshed successfully"
            return $true
        } else {
            Write-Log "⚠️ Disk refresh completed with warnings"
            return $false
        }
    } catch {
        Write-Log "❌ Error refreshing disk information: $_"
        return $false
    }
}

# Function to expand Windows partition using multiple methods
function Expand-WindowsPartition {
    param (
        [string]$computerName,
        [string]$driveLetter = "C"
    )
    
    try {
        Write-Log "Starting Windows partition expansion for drive $driveLetter on $computerName..."
        
        # First, refresh disk information to detect new space
        Refresh-DiskInfo -computerName $computerName
        
        # Method 1: Try PowerShell Resize-Partition first (Windows 8/2012+)
        Write-Log "Attempting Method 1: PowerShell Resize-Partition..."
        $method1Result = Invoke-Command -ComputerName $computerName -ScriptBlock {
            param($driveLetter)
            try {
                # Get the partition for the specified drive
                $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
                Write-Output "Found partition: $($partition.PartitionNumber) on disk $($partition.DiskNumber)"
                
                # Get current partition size
                $currentSize = $partition.Size
                Write-Output "Current partition size: $([math]::Round($currentSize / 1GB, 2)) GB"
                
                # Get maximum supported size
                $maxSize = (Get-PartitionSupportedSize -DriveLetter $driveLetter -ErrorAction Stop).SizeMax
                Write-Output "Maximum supported size: $([math]::Round($maxSize / 1GB, 2)) GB"
                
                # Check if there's actually space to expand
                if ($maxSize -gt $currentSize) {
                    $expansionSize = $maxSize - $currentSize
                    Write-Output "Expansion possible: $([math]::Round($expansionSize / 1GB, 2)) GB can be added"
                    
                    # Resize the partition to maximum size
                    Resize-Partition -DriveLetter $driveLetter -Size $maxSize -Confirm:$false -ErrorAction Stop
                    Write-Output "SUCCESS: Partition resized from $([math]::Round($currentSize / 1GB, 2)) GB to $([math]::Round($maxSize / 1GB, 2)) GB"
                    
                    # Verify the resize worked
                    Start-Sleep -Seconds 2
                    $partitionAfter = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
                    $sizeAfter = $partitionAfter.Size
                    Write-Output "Verified size after resize: $([math]::Round($sizeAfter / 1GB, 2)) GB"
                    
                    if ($sizeAfter -gt $currentSize) {
                        Write-Output "VERIFIED: Partition expansion successful"
                        return $true
                    } else {
                        Write-Output "WARNING: Resize command succeeded but size did not change"
                        return $false
                    }
                } else {
                    Write-Output "No expansion needed - partition already at maximum size"
                    return $true
                }
            } catch {
                Write-Output "PowerShell method failed: $_"
                return $false
            }
        } -ArgumentList $driveLetter -ErrorAction SilentlyContinue
        
        if ($method1Result -eq $true) {
            Write-Log "✅ Windows partition expansion completed using PowerShell method"
            return $true
        }
        
        # Method 2: Use diskpart with dynamic partition detection
        Write-Log "Attempting Method 2: Diskpart with dynamic partition detection..."
        $method2Result = Invoke-Command -ComputerName $computerName -ScriptBlock {
            param($driveLetter)
            try {
                # First, get the partition number for the C: drive
                $partitionInfo = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
                $partitionNumber = $partitionInfo.PartitionNumber
                $diskNumber = $partitionInfo.DiskNumber
                
                Write-Output "Detected partition $partitionNumber on disk $diskNumber for drive $driveLetter"
                
                # Create diskpart script with detected partition
                $diskpartScript = @"
list disk
select disk $diskNumber
list partition
select partition $partitionNumber
extend
exit
"@
                
                # Create temp directory if it doesn't exist
                $tempDir = "C:\Temp"
                if (-not (Test-Path $tempDir)) {
                    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
                }
                
                # Write diskpart script to file
                $scriptPath = "$tempDir\extend_partition_dynamic.txt"
                Set-Content -Path $scriptPath -Value $diskpartScript -Encoding ASCII
                
                Write-Output "Executing diskpart script with partition $partitionNumber..."
                
                # Execute diskpart with the script
                $diskpartOutput = & diskpart /s $scriptPath 2>&1
                
                # Clean up the script file
                Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
                
                # Return the output
                return $diskpartOutput
                
            } catch {
                Write-Output "Diskpart method failed: $_"
                return $null
            }
        } -ArgumentList $driveLetter -ErrorAction SilentlyContinue
        
        if ($method2Result) {
            Write-Log "Diskpart output: $($method2Result -join '; ')"
            
            # Check if extension was successful
            if ($method2Result -match "successfully extended" -or $method2Result -match "DiskPart successfully extended" -or $method2Result -match "extended") {
                Write-Log "✅ Windows partition expanded successfully using diskpart method"
                return $true
            } else {
                Write-Log "⚠️ Diskpart completed but extension status unclear"
            }
        }
        
        # Method 3: Try diskpart with volume selection (alternative approach)
        Write-Log "Attempting Method 3: Diskpart with volume selection..."
        $method3Result = Invoke-Command -ComputerName $computerName -ScriptBlock {
            param($driveLetter)
            try {
                # Create diskpart script using volume selection
                $diskpartScript = @"
list volume
select volume $driveLetter
extend
exit
"@
                
                # Create temp directory if it doesn't exist
                $tempDir = "C:\Temp"
                if (-not (Test-Path $tempDir)) {
                    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
                }
                
                # Write diskpart script to file
                $scriptPath = "$tempDir\extend_volume.txt"
                Set-Content -Path $scriptPath -Value $diskpartScript -Encoding ASCII
                
                Write-Output "Executing diskpart script with volume selection..."
                
                # Execute diskpart with the script
                $diskpartOutput = & diskpart /s $scriptPath 2>&1
                
                # Clean up the script file
                Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
                
                # Return the output
                return $diskpartOutput
                
            } catch {
                Write-Output "Volume selection method failed: $_"
                return $null
            }
        } -ArgumentList $driveLetter -ErrorAction SilentlyContinue
        
        if ($method3Result) {
            Write-Log "Diskpart volume output: $($method3Result -join '; ')"
            
            # Check if extension was successful
            if ($method3Result -match "successfully extended" -or $method3Result -match "DiskPart successfully extended" -or $method3Result -match "extended") {
                Write-Log "✅ Windows partition expanded successfully using volume selection method"
                return $true
            }
        }
        
        Write-Log "❌ All partition expansion methods failed"
        return $false
        
    } catch {
        Write-Log "❌ Error expanding Windows partition: $_"
        return $false
    }
}

# Function to get disk information from remote computer
function Get-RemoteDiskInfo {
    param ([string]$computerName)
    
    try {
        $session = New-PSSession -ComputerName $computerName -ErrorAction Stop
        $disk = Invoke-Command -Session $session -ScriptBlock {
            Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | 
            Select-Object Size, FreeSpace
        }
        Remove-PSSession $session
        return $disk
    } catch {
        Write-Log "ERROR: Failed to retrieve disk info from $computerName. $_"
        return $null
    }
}

# Function to get detailed disk and partition information for troubleshooting
function Get-DetailedDiskInfo {
    param ([string]$computerName)
    
    try {
        $session = New-PSSession -ComputerName $computerName -ErrorAction Stop
        $diskInfo = Invoke-Command -Session $session -ScriptBlock {
            try {
                # Get logical disk info
                $logicalDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
                
                # Get partition info
                $partition = Get-Partition -DriveLetter "C" -ErrorAction SilentlyContinue
                
                # Get disk info
                $disk = Get-Disk -Number 0 -ErrorAction SilentlyContinue
                
                return @{
                    LogicalDisk = $logicalDisk
                    Partition = $partition
                    Disk = $disk
                }
            } catch {
                Write-Output "Error getting detailed disk info: $_"
                return $null
            }
        }
        Remove-PSSession $session
        return $diskInfo
    } catch {
        Write-Log "ERROR: Failed to retrieve detailed disk info from $computerName. $_"
        return $null
    }
}

# Ensure CSV has header
if (-not (Test-Path $csvPath)) {
    "VMName,VM_DiskSizeGB,CDriveSizeGB,CFreeSpaceGBBefore,ExpandedVM_DiskSizeGB,CFreeSpaceGBAfter,LastUpdate,Status" | Out-File -FilePath $csvPath -Encoding UTF8
}

# Start Logging
Write-Log "=== Starting disk check for $vmName ==="
Write-Log "Target free space: $desiredFreeSpaceGB GB"

# Connect to vCenter
try {
    Connect-VIServer -Server $vCenterServer -ErrorAction Stop
    Write-Log "Connected to vCenter: $vCenterServer"
} catch {
    Write-Log "ERROR: Failed to connect to vCenter. $_"
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore 0 -cDriveSize 0 -freeSpaceBefore 0 -vmDiskSizeAfter 0 -freeSpaceAfter 0 -status "Error - vCenter Connect"
    exit 1
}

# Get VM object
try {
    $vm = Get-VM -Name $vmName -ErrorAction Stop
    Write-Log "Found VM: $vmName"
} catch {
    Write-Log "ERROR: VM $vmName not found. $_"
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore 0 -cDriveSize 0 -freeSpaceBefore 0 -vmDiskSizeAfter 0 -freeSpaceAfter 0 -status "Error - VM Not Found"
    exit 1
}

# Get current disk usage inside guest
$disk = Get-RemoteDiskInfo -computerName $vmName
if (-not $disk) {
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore 0 -cDriveSize 0 -freeSpaceBefore 0 -vmDiskSizeAfter 0 -freeSpaceAfter 0 -status "Error - Disk Info"
    exit 1
}

$total = [math]::Round($disk.Size / 1GB, 2)
$free = [math]::Round($disk.FreeSpace / 1GB, 2)
$currentFreeSpaceGB = $free

Write-Log "C: Drive - Total: $total GB, Free: $free GB"

if ($currentFreeSpaceGB -lt $desiredFreeSpaceGB) {
    $used = $total - $free
    $requiredTotal = [math]::Ceiling($used + $desiredFreeSpaceGB)

    if ($requiredTotal -gt $total) {
        Write-Log "Expanding disk from $total GB to $requiredTotal GB to achieve $desiredFreeSpaceGB GB free space..."

        # Step 1: Expand VMware disk
        try {
            $hardDisk = Get-HardDisk -VM $vm | Where-Object {$_.Name -eq "Hard disk 1"} -ErrorAction Stop
            Set-HardDisk -HardDisk $hardDisk -CapacityGB $requiredTotal -Confirm:$false -ErrorAction Stop
            Write-Log "✅ VMware disk expanded successfully to $requiredTotal GB"
        } catch {
            Write-Log "❌ ERROR: Failed to expand VMware disk. $_"
            Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $total -freeSpaceAfter $currentFreeSpaceGB -status "Error - VMware Expansion"
            exit 1
        }

        # Step 2: Wait a moment for VMware to recognize the change
        Write-Log "Waiting 10 seconds for VMware to recognize disk change..."
        Start-Sleep -Seconds 10

        # Step 2.5: Get detailed disk info for troubleshooting
        Write-Log "Getting detailed disk information for troubleshooting..."
        $detailedInfo = Get-DetailedDiskInfo -computerName $vmName
        if ($detailedInfo) {
            $diskSizeGB = [math]::Round($detailedInfo.Disk.Size / 1GB, 2)
            $partitionSizeGB = [math]::Round($detailedInfo.Partition.Size / 1GB, 2)
            Write-Log "Physical disk size: $diskSizeGB GB, Partition size: $partitionSizeGB GB"
        }

        # Step 3: Expand Windows partition
        $partitionExpanded = Expand-WindowsPartition -computerName $vmName -driveLetter "C"
        
        if ($partitionExpanded) {
            Write-Log "✅ Windows partition expansion completed successfully"
            
            # Step 4: Wait for partition changes to take effect
            Write-Log "Waiting 15 seconds for partition changes to take effect..."
            Start-Sleep -Seconds 15
            
            # Step 4.5: Refresh disk info again and retry if needed
            Write-Log "Refreshing disk information after partition expansion..."
            Refresh-DiskInfo -computerName $vmName
            
            # Check if partition actually expanded, if not, try again
            $checkInfo = Get-DetailedDiskInfo -computerName $vmName
            if ($checkInfo) {
                $currentPartitionSize = [math]::Round($checkInfo.Partition.Size / 1GB, 2)
                $currentDiskSize = [math]::Round($checkInfo.Disk.Size / 1GB, 2)
                
                Write-Log "After expansion - Physical disk: $currentDiskSize GB, Partition: $currentPartitionSize GB"
                
                # If partition size is still much smaller than disk size, try expansion again
                if ($currentPartitionSize -lt ($currentDiskSize - 1)) {
                    Write-Log "Partition size still smaller than disk size, attempting expansion again..."
                    
                    # Refresh disk info again before retry
                    Refresh-DiskInfo -computerName $vmName
                    Start-Sleep -Seconds 5
                    
                    $retryExpanded = Expand-WindowsPartition -computerName $vmName -driveLetter "C"
                    if ($retryExpanded) {
                        Write-Log "✅ Retry expansion completed"
                        Start-Sleep -Seconds 10
                        
                        # Check again after retry
                        $finalCheckInfo = Get-DetailedDiskInfo -computerName $vmName
                        if ($finalCheckInfo) {
                            $finalPartitionSize = [math]::Round($finalCheckInfo.Partition.Size / 1GB, 2)
                            $finalDiskSize = [math]::Round($finalCheckInfo.Disk.Size / 1GB, 2)
                            Write-Log "After retry - Physical disk: $finalDiskSize GB, Partition: $finalPartitionSize GB"
                        }
                    }
                } else {
                    Write-Log "✅ Partition size matches disk size - expansion successful"
                }
            }
            
            # Step 5: Verify the expansion worked
            $diskUpdated = Get-RemoteDiskInfo -computerName $vmName
            $detailedInfoUpdated = Get-DetailedDiskInfo -computerName $vmName
            
            if ($diskUpdated) {
                $newTotal = [math]::Round($diskUpdated.Size / 1GB, 2)
                $newFree = [math]::Round($diskUpdated.FreeSpace / 1GB, 2)
                $newFreeSpaceGB = $newFree

                Write-Log "✅ New C: Drive Stats - Total: $newTotal GB, Free: $newFree GB"
                
                # Get detailed info for comparison
                if ($detailedInfoUpdated) {
                    $newDiskSizeGB = [math]::Round($detailedInfoUpdated.Disk.Size / 1GB, 2)
                    $newPartitionSizeGB = [math]::Round($detailedInfoUpdated.Partition.Size / 1GB, 2)
                    Write-Log "Updated Physical disk size: $newDiskSizeGB GB, Partition size: $newPartitionSizeGB GB"
                }
                
                # Verify that the expansion actually worked
                if ($newTotal -gt $total) {
                    Write-Log "✅ SUCCESS: Drive successfully expanded from $total GB to $newTotal GB"
                    Write-Log "✅ Free space increased from $currentFreeSpaceGB GB to $newFreeSpaceGB GB"
                    
                    # Check if we achieved the target free space
                    if ($newFreeSpaceGB -ge $desiredFreeSpaceGB) {
                        Write-Log "✅ TARGET ACHIEVED: Free space target of $desiredFreeSpaceGB GB met!"
                        Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $newTotal -freeSpaceAfter $newFreeSpaceGB -status "Successfully Expanded - Target Met"
                    } else {
                        Write-Log "⚠️ PARTIAL SUCCESS: Drive expanded but free space target not fully met"
                        Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $newTotal -freeSpaceAfter $newFreeSpaceGB -status "Successfully Expanded - Partial Target"
                    }
                } else {
                    Write-Log "⚠️ WARNING: VMware disk expanded but Windows partition size unchanged"
                    Write-Log "Troubleshooting info: Physical disk may need to be refreshed or partition table updated"
                    Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $requiredTotal -freeSpaceAfter $currentFreeSpaceGB -status "VMware Expanded - Partition Issue"
                }
            } else {
                Write-Log "❌ ERROR: Could not retrieve updated disk info for verification"
                Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $requiredTotal -freeSpaceAfter 0 -status "Error - Verification Failed"
            }
        } else {
            Write-Log "❌ ERROR: Failed to expand Windows partition"
            Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $requiredTotal -freeSpaceAfter $currentFreeSpaceGB -status "Error - Partition Expansion Failed"
        }

        Write-Log "=== Disk expansion process completed for $vmName ==="
    } else {
        Write-Log "Calculated required size ($requiredTotal GB) is not greater than current size ($total GB). No action taken."
        Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $total -freeSpaceAfter $currentFreeSpaceGB -status "No Action - Size Calculation"
    }
} else {
    Write-Log "No expansion needed. Free space ($currentFreeSpaceGB GB) is sufficient (target: $desiredFreeSpaceGB GB)."
    Append-CsvLog -vmName $vmName -vmDiskSizeBefore $total -cDriveSize $total -freeSpaceBefore $currentFreeSpaceGB -vmDiskSizeAfter $total -freeSpaceAfter $currentFreeSpaceGB -status "No Action - Sufficient Space"
}

Write-Log "=== Script completed for $vmName ==="

# Disconnect from vCenter
try {
    Disconnect-VIServer -Server $vCenterServer -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Disconnected from vCenter"
} catch {
    Write-Log "Note: Could not disconnect from vCenter (this is usually not critical)"
}
