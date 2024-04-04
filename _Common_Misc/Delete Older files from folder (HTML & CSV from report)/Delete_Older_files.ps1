#region Check if the Reports folder exists, and create it if not. And delete .HTML & .CSV files older than 60 days

$reportsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Reports"
if (-not (Test-Path -Path $reportsFolderPath -PathType Container)) {
    Write-Host "Reprots folder not found. Creating folder.." -ForegroundColor Yellow
    New-Item -Path $reportsFolderPath -ItemType Directory
}

# Get CSV and HTML files older than 60 days in the Reports folder
$oldFiles = Get-ChildItem -Path $reportsFolderPath | Where-Object { $_.Extension -eq '.csv' -or $_.Extension -eq '.html' -or $_.Extension -eq '.txt' -and $_.CreationTime -lt (Get-Date).AddDays(-60) }
$oldFiles.count

# Check if old files were found before attempting to delete them
if ($oldFiles.Count -gt 0) {
    # Delete the old CSV and HTML files
    foreach ($file in $oldFiles) {
        Remove-Item -Path $file.FullName -Force
    }
    Write-Verbose "$($oldFiles.Count) Old CSV and HTML files deleted."
}
else {
    Write-Host "No old CSV and HTML files found."
}
#endregion Check if the Reports folder exists, and create it if not. And delete .HTML & .CSV files older than 60 days 
