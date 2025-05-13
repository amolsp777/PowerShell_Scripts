# VM Scheduled Tasks Management

This repository contains three PowerShell scripts designed to manage scheduled tasks related to virtual machines (VMs). These scripts help in retrieving, removing, and scheduling snapshot tasks for VMs in a virtualized environment.

## Scripts

### 1. `Get-VMscheduledTasks.ps1`
Retrieves and displays all scheduled tasks associated with virtual machines. This script is useful for auditing and monitoring scheduled operations on VMs.

**Usage:**
```powershell
.\Get-VMscheduledTasks.ps1
```

## 2. `Remove-VMscheduledTasks.ps1`

Removes scheduled tasks from virtual machines. Use this script to clean up outdated or unnecessary scheduled tasks.

**Usage:**
```powershell
.\Remove-VMscheduledTasks.ps1
```

## 3. `Schedule_Snapshots.ps1`

Schedules snapshot tasks for virtual machines. This script helps automate the creation of VM snapshots at specified intervals.

**Usage:**
```powershell
.\Schedule_Snapshots.ps1
```

## Requirements
- PowerShell 5.1 or later
- Administrator privileges
- Access to the virtual environment (e.g., Hyper-V, VMware, etc.)

## Notes
Ensure you have the necessary permissions to execute these scripts.
Test scripts in a development environment before deploying to production.

## Keywords

`PowerShell`, `VM Management`, `Scheduled Tasks`, `Virtual Machines`, `Snapshots`, `Automation`, `VMware`, `Scripting`, `Infrastructure Automation`
