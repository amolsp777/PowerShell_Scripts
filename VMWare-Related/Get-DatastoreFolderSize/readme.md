# Datastore Folder Size Utilization Script

This PowerShell script, **Get-DatastoreFolderSize.ps1**, is designed to provide information about VM folder sizes within a specified datastore using PowerCLI. It enables you to quickly assess the utilization of space within a datastore by examining the sizes of VM folders contained within.

## Usage

### Prerequisites
- VMware PowerCLI module installed.
- Connected to a vCenter Server.

### Instructions
1. Run the script by executing the following command:
    ```powershell
    Connect-VIServer -Server "vcname"
    Get-DatastoreFolderSize -Datastore (Get-Datastore 'mydatastore')
    ```

2. Replace `"vcname"` with the name or IP address of your vCenter Server.
3. Replace `'mydatastore'` with the name of the datastore you want to analyze.

### Parameters

- `-Datastore`: Specifies the datastore for which you want to check the utilization. It accepts input as a string representing the datastore name.
- `-ExportToCSV`: Optional switch parameter. If set to `$true`, it generates a CSV report of the folder sizes.

### Examples

```powershell
# Get folder sizes for a specific datastore
Get-DatastoreFolderSize -Datastore (Get-Datastore 'mydatastore')

# Pipe datastore name directly into the function
Get-Datastore SA-shared-01-ms-remote | Get-DatastoreFolderSize

# Export results to CSV
Get-Datastore SA-shared-01-ms-remote | Get-DatastoreFolderSize -ExportToCSV:$true
```
### Notes
Author: Ankush Sethi
Blog: www.vmwarecode.com
Description
The script utilizes VMware PowerCLI to retrieve information about VM folder sizes within the specified datastore. It calculates the size of each folder in megabytes (MB) and gigabytes (GB) and provides additional details such as total files and last modified date.

### Output
The output includes the following information for each VM folder within the datastore:

Folderpath: Path of the VM folder.
FolderSize-MB: Size of the folder in megabytes.
FolderSpace-GB: Size of the folder in gigabytes.
TotalFiles: Total number of files within the folder.
Last-Modified: Date when the folder was last modified.
Export to CSV
If the -ExportToCSV switch is used, the script exports the output to a CSV file named VMwareCode_VMfolderReport_VCName.csv, where VCName is the name of the vCenter Server. The CSV file contains the same information as displayed in the console output.