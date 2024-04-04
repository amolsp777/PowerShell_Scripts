# Delete Older files from folder (HTML & CSV from report)

## Reports Folder Maintenance Script

This PowerShell script is designed to manage the maintenance of the "Reports" folder within your system. The script performs two primary tasks:

1. **Check and Create Reports Folder**: It verifies the existence of the "Reports" folder within the directory where the script is executed. If the folder doesn't exist, the script creates it.

2. **Delete Old Files**: The script identifies and removes CSV, HTML, and TXT files that are older than 60 days from the "Reports" folder.

## How to Use

### Running the Script

1. **Download**: Download the script file provided.

2. **Execution**:
   - Open PowerShell.
   - Navigate to the directory where the script is saved.
   - Run the script by typing `.\Delete_Older_files.ps1` and pressing Enter.

## Script Overview

### Check and Create Reports Folder

- The script first checks if the "Reports" folder exists.
- If the folder doesn't exist, it creates one in the directory where the script is located.

### Delete Old Files

- It retrieves a list of CSV, HTML, and TXT files older than 60 days from the "Reports" folder.
- Any old files found are deleted from the folder.
- The script provides feedback on the number of old files deleted.

## Important Notes

- Ensure the script is executed in the correct directory where the "Reports" folder should be maintained.
- Customize the script if the folder structure or file types differ from those assumed (CSV, HTML, and TXT).

## Script Details

```powershell
#region Check if the Reports folder exists, and create it if not. And delete .HTML & .CSV files older than 60 days

$reportsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Reports"
if (-not (Test-Path -Path $reportsFolderPath -PathType Container)) {
    Write-Host "Reports folder not found. Creating folder.." -ForegroundColor Yellow
    New-Item -Path $reportsFolderPath -ItemType Directory
}

# Get CSV, HTML, and TXT files older than 60 days in the Reports folder
$oldFiles = Get-ChildItem -Path $reportsFolderPath | Where-Object { $_.Extension -eq '.csv' -or $_.Extension -eq '.html' -or $_.Extension -eq '.txt' -and $_.CreationTime -lt (Get-Date).AddDays(-60) }
$oldFiles.count

# Check if old files were found before attempting to delete them
if ($oldFiles.Count -gt 0) {
    # Delete the old CSV, HTML, and TXT files
    foreach ($file in $oldFiles) {
        Remove-Item -Path $file.FullName -Force
    }
    Write-Verbose "$($oldFiles.Count) Old CSV, HTML, and TXT files deleted."
}
else {
    Write-Host "No old CSV, HTML, and TXT files found."
}
#endregion Check if the Reports folder exists, and create it if not. And delete .HTML & .CSV files older than 60 days 
