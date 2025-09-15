# VM Disk Expansion Script v4

## Overview

The VM Disk Expansion Script v4 is a PowerShell automation tool designed to automatically expand VMware virtual machine disks and Windows partitions to ensure a specified amount of free space is available on the C: drive.

## Key Features

### ✅ **Fixed Free Space Target**
- Uses a fixed GB amount (e.g., 20 GB) instead of percentage-based calculations
- More predictable and practical for automation scenarios
- Consistent results regardless of disk size

### ✅ **Multi-Method Partition Expansion**
- **Method 1**: PowerShell `Resize-Partition` (primary method)
- **Method 2**: Diskpart with dynamic partition detection
- **Method 3**: Diskpart with volume selection (fallback)
- Automatic fallback if primary method fails

### ✅ **Enhanced Disk Refresh**
- PowerShell `Update-Disk` and `Update-Partition` commands
- Diskpart `rescan` command to force disk detection
- Multiple refresh attempts with proper timing

### ✅ **Comprehensive Verification**
- Real-time monitoring of partition vs disk sizes
- Immediate verification after each expansion attempt
- Automatic retry logic if expansion doesn't work initially

### ✅ **Detailed Logging & Reporting**
- Comprehensive log files with timestamps
- CSV reporting for tracking expansion history
- Clear success/failure indicators with emojis
- Detailed troubleshooting information

## Prerequisites

### System Requirements
- **PowerShell 5.1+** or **PowerShell Core 6+**
- **VMware PowerCLI** module installed
- **Administrative privileges** on both management machine and target VMs
- **Network connectivity** to vCenter and target VMs

### Required Modules
```powershell
# Install VMware PowerCLI
Install-Module -Name VMware.PowerCLI -Force

# Verify installation
Get-Module -ListAvailable VMware.PowerCLI
```

### Permissions Required
- **vCenter**: Read/Write access to VM configuration
- **Target VM**: Local administrator or equivalent privileges
- **Network**: WinRM enabled on target VMs for remote execution

## Configuration

### Script Parameters
Edit the following parameters at the top of the script:

```powershell
# Parameters
$vmName = "VMNAME1"                     # Target VM name
$desiredFreeSpaceGB = 20                # Target free space in GB
$vCenterServer = "VC-FQDN"              # vCenter server FQDN
```

### File Paths
The script automatically creates the following files:
- **Log File**: `VM_DiskExpansion_<VMName>.log`
- **CSV Report**: `VM_DiskExpansion_Report_v4.csv`

## Usage

### Basic Usage
```powershell
# Run the script
.\Get_Set_VM_DiskExpansion_v4.ps1
```

### Batch Processing
For multiple VMs, modify the script parameters and run:
```powershell
# Example for multiple VMs
$vmList = @("VM1", "VM2", "VM3")
foreach ($vm in $vmList) {
    $vmName = $vm
    .\Get_Set_VM_DiskExpansion_v4.ps1
}
```

## How It Works

### 1. **Initial Assessment**
- Connects to vCenter and locates the target VM
- Retrieves current disk usage from the Windows guest OS
- Calculates required disk size: `Used Space + Target Free Space`

### 2. **VMware Disk Expansion**
- Expands the VMware virtual disk to the calculated size
- Waits for VMware to recognize the disk change

### 3. **Windows Partition Expansion**
- Refreshes disk information using multiple methods
- Attempts partition expansion using three different approaches:
  - PowerShell `Resize-Partition` (primary)
  - Diskpart with dynamic partition detection
  - Diskpart with volume selection

### 4. **Verification & Retry**
- Verifies that the partition actually expanded
- Retries expansion if initial attempt fails
- Confirms target free space was achieved

### 5. **Reporting**
- Logs all activities with timestamps
- Updates CSV report with results
- Provides clear success/failure status

## Output Examples

### Successful Expansion
```
=== Starting disk check for VMNAME ===
Target free space: 20 GB
Connected to vCenter: vc.apshell.com
Found VM: VMNAME
C: Drive - Total: 80 GB, Free: 5 GB
Expanding disk from 80 GB to 100 GB to achieve 20 GB free space...
✅ VMware disk expanded successfully to 100 GB
✅ Windows partition expansion completed using PowerShell method
✅ SUCCESS: Drive successfully expanded from 80 GB to 100 GB
✅ Free space increased from 5 GB to 25 GB
✅ TARGET ACHIEVED: Free space target of 20 GB met!
```

### CSV Report Sample
| VMName | VM_DiskSizeGB | CDriveSizeGB | CFreeSpaceGBBefore | ExpandedVM_DiskSizeGB | CFreeSpaceGBAfter | LastUpdate | Status |
|--------|---------------|--------------|-------------------|----------------------|-------------------|------------|---------|
| VMNAME | 80 | 80 | 5 | 100 | 25 | 2024-01-15 10:30:00 | Successfully Expanded - Target Met |

## Status Codes

### Success Statuses
- **"Successfully Expanded - Target Met"**: Full target achieved
- **"Successfully Expanded - Partial Target"**: Expanded but target not fully met
- **"No Action - Sufficient Space"**: Already has enough free space

### Error Statuses
- **"Error - vCenter Connect"**: Cannot connect to vCenter
- **"Error - VM Not Found"**: Target VM not found
- **"Error - VMware Expansion"**: VMware disk expansion failed
- **"Error - Partition Expansion Failed"**: Windows partition expansion failed
- **"VMware Expanded - Partition Issue"**: VMware expanded but Windows partition didn't

## Troubleshooting

### Common Issues

#### 1. **"VMware disk expanded but Windows partition size unchanged"**
**Cause**: Windows hasn't detected the new disk space
**Solution**: The script automatically retries with disk refresh

#### 2. **"Failed to connect to vCenter"**
**Causes**:
- Incorrect vCenter server name
- Network connectivity issues
- Invalid credentials
- PowerCLI not installed

**Solutions**:
```powershell
# Test connectivity
Test-NetConnection -ComputerName "vc.apshell.com" -Port 443

# Verify PowerCLI
Get-Module -ListAvailable VMware.PowerCLI

# Test vCenter connection
Connect-VIServer -Server "vc.apshell.com"
```

#### 3. **"Failed to retrieve disk info from VM"**
**Causes**:
- WinRM not enabled on target VM
- Network connectivity issues
- Insufficient permissions
- VM is powered off

**Solutions**:
```powershell
# Enable WinRM on target VM
winrm quickconfig

# Test connectivity
Test-NetConnection -ComputerName "VMNAME" -Port 5985

# Test PowerShell remoting
Invoke-Command -ComputerName "VMNAME" -ScriptBlock { Get-Date }
```

#### 4. **"All partition expansion methods failed"**
**Causes**:
- Partition is not the last partition on disk
- Disk is offline
- File system corruption
- Insufficient permissions

**Solutions**:
- Check partition layout: `Get-Partition -DiskNumber 0`
- Ensure disk is online: `Get-Disk -Number 0`
- Run disk check: `chkdsk C: /f`

### Diagnostic Tools

#### Run Diagnostic Script
```powershell
# Copy and run diagnostic script on target VM
.\VM_DiskExpansion_Diagnostic.ps1 -VMName "VMNAME" -DriveLetter "C"
```

#### Manual Verification
```powershell
# Check disk and partition sizes
Get-Disk -Number 0 | Select-Object Size, OperationalStatus
Get-Partition -DriveLetter C | Select-Object Size, Offset
Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object Size, FreeSpace
```

## Best Practices

### 1. **Pre-Expansion Checks**
- Ensure VM is powered on
- Verify network connectivity
- Check available storage on datastore
- Confirm VM has no snapshots

### 2. **Timing Considerations**
- Run during maintenance windows
- Allow sufficient time for expansion (5-15 minutes per VM)
- Monitor disk I/O during expansion

### 3. **Backup Recommendations**
- Create VM snapshots before expansion
- Backup critical data
- Test expansion on non-production VMs first

### 4. **Monitoring**
- Review log files after each run
- Monitor CSV reports for trends
- Set up alerts for failed expansions

## Version History

### v4.0 (Current)
- ✅ Fixed free space target (GB instead of percentage)
- ✅ Enhanced disk refresh with diskpart rescan
- ✅ Improved verification and retry logic
- ✅ Better error handling and logging
- ✅ Comprehensive CSV reporting

### v3.0
- ✅ Multiple partition expansion methods
- ✅ Dynamic partition detection
- ✅ Enhanced troubleshooting

### v2.0
- ✅ Basic VMware and Windows expansion
- ✅ CSV logging

### v1.0
- ✅ Initial release with percentage-based expansion

## Support

For issues or questions:
1. Check the log files for detailed error information
2. Run the diagnostic script for troubleshooting
3. Review the troubleshooting section above
4. Verify all prerequisites are met

## License

This script is provided as-is for internal use. Modify as needed for your environment.

---

**Last Updated**: January 2024  
**Version**: 4.0  
**Author**: VM Automation Team
