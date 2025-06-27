$log = "C:\Temp\disk-init.log"

function Write-Log {
    param($message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "$timestamp - $message"
    Write-Output $entry
    Add-Content -Path $log -Value $entry
}

Write-Log "=== Script Start ==="

try {
    # Get all offline disks that are RAW or have no partitions
    $disks = Get-Disk | Where-Object {
        $_.IsOffline -or $_.PartitionStyle -eq 'RAW' -or (Get-Partition -DiskNumber $_.Number -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0
    }

    if ($disks.Count -eq 0) {
        Write-Log "No disks found that need partitioning."
    } else {
        # Get used drive letters from Volume and WMI and sanitize them
        $usedLettersFromVolumes = Get-Volume | Where-Object DriveLetter | Select-Object -ExpandProperty DriveLetter
        $usedLettersFromWMI = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter } | Select-Object -ExpandProperty DriveLetter
        $usedLetters = @($usedLettersFromVolumes + $usedLettersFromWMI) | ForEach-Object {
            $_.ToString().TrimEnd(':').ToUpper()
        } | Sort-Object -Unique

        Write-Log "Currently used drive letters: $($usedLetters -join ', ')"

        foreach ($disk in $disks) {
            $diskNumber = $disk.Number
            Write-Log "Processing disk $diskNumber..."

            # Get updated disk info
            $disk = Get-Disk -Number $diskNumber

            Write-Log "Disk $diskNumber info:"
            Write-Log "  FriendlyName : $($disk.FriendlyName)"
            Write-Log "  OperationalStatus : $($disk.OperationalStatus)"
            Write-Log "  IsOffline : $($disk.IsOffline)"
            Write-Log "  IsReadOnly : $($disk.IsReadOnly)"
            Write-Log "  PartitionStyle : $($disk.PartitionStyle)"
            Write-Log "  Size (GB) : $([math]::Round($disk.Size / 1GB, 2))"

            if ($disk.IsOffline) {
                Write-Log "Disk $diskNumber is offline. Bringing it online..."
                Set-Disk -Number $diskNumber -IsOffline $false -ErrorAction Stop
                Write-Log "Disk $diskNumber is now online."
            }

            if ($disk.IsReadOnly) {
                Write-Log "Disk $diskNumber is read-only. Clearing read-only flag..."
                Set-Disk -Number $diskNumber -IsReadOnly $false -ErrorAction Stop
                Write-Log "Read-only flag cleared on disk $diskNumber."
            }

            # Clean disk to remove partitions
            Write-Log "Cleaning disk $diskNumber to remove all existing partitions..."
            Clear-Disk -Number $diskNumber -RemoveData -Confirm:$false -ErrorAction Stop
            Write-Log "Disk $diskNumber cleaned."

            # Initialize disk with GPT
            Write-Log "Initializing disk $diskNumber with GPT..."
            Initialize-Disk -Number $diskNumber -PartitionStyle GPT -ErrorAction Stop

            # Refresh used letters before assigning new drive letter
            $usedLettersFromVolumes = Get-Volume | Where-Object DriveLetter | Select-Object -ExpandProperty DriveLetter
            $usedLettersFromWMI = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter } | Select-Object -ExpandProperty DriveLetter
            $usedLetters = @($usedLettersFromVolumes + $usedLettersFromWMI) | ForEach-Object {
                $_.ToString().TrimEnd(':').ToUpper()
            } | Sort-Object -Unique

            Write-Log "Currently used drive letters: $($usedLetters -join ', ')"

            # Determine available drive letters (C-Z excluding used ones)
            $allLetters = [char[]](71..90)  # G to Z
            $availableLetters = $allLetters | Where-Object { $usedLetters -notcontains $_ }

            if ($availableLetters.Count -eq 0) {
                Write-Log "No available drive letters to assign for disk $diskNumber."
                continue
            }

            $driveLetterToAssign = $availableLetters[0]
            Write-Log "Creating new partition on disk $diskNumber with drive letter $driveLetterToAssign..."

            $newPartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -DriveLetter $driveLetterToAssign -ErrorAction Stop

            Format-Volume -Partition $newPartition -FileSystem NTFS -NewFileSystemLabel "DataDisk" -Confirm:$false -ErrorAction Stop

            Write-Log "New partition created and formatted on disk $diskNumber with drive letter $driveLetterToAssign."
        }
    }
} catch {
    Write-Log "ERROR: $_"
}

Write-Log "=== Script End ==="
