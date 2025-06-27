# Disk Initialization and Formatting Script

This PowerShell script automates the process of initializing and formatting new or offline disks in Windows systems. It's particularly useful in server environments or when setting up new storage devices.

## Features

- Automatically detects offline, RAW, or unpartitioned disks
- Initializes disks with GPT partition style
- Creates new partitions using maximum available space
- Formats partitions with NTFS
- Automatically assigns available drive letters (G-Z)
- Comprehensive logging to track operations
- Error handling and recovery

## Prerequisites

- Windows PowerShell 5.1 or later
- Administrator privileges required
- Windows Server or Windows Professional/Enterprise editions

## Usage

1. Open PowerShell as Administrator
2. Navigate to the script directory
3. Run the script:
   ```powershell
   .\Get-disk_and_formate.ps1
   ```

## Logging

The script logs all operations to `C:\Temp\disk-init.log`. This log file includes:
- Timestamps for each operation
- Disk processing details
- Error messages (if any)
- Drive letter assignments
- Partition creation and formatting status

## What the Script Does

1. Scans for:
   - Offline disks
   - RAW disks (no partition style)
   - Disks with no partitions

2. For each detected disk:
   - Brings the disk online (if offline)
   - Clears read-only flag (if set)
   - Removes existing partitions
   - Initializes with GPT partition style
   - Creates a new partition using maximum space
   - Formats the partition as NTFS
   - Assigns an available drive letter (G-Z)

## Safety Features

- Verifies disk status before operations
- Checks for available drive letters
- Maintains comprehensive logging
- Includes error handling
- Uses non-destructive operations where possible

## Notes

- The script uses drive letters G-Z to avoid conflicts with system drives
- All operations are logged for audit and troubleshooting
- The script requires administrator privileges to modify disk configurations

## License

This script is provided as-is without warranty of any kind. Use at your own risk.

## Support

For support or questions, please contact the script maintainer.
