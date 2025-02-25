# PowerShell Script: Directory Creation and Path Assignment

## Description

This PowerShell script is designed to create a directory named `Report` in the script's root directory if it does not already exist. It then assigns the path of this directory to the variable `$ReportPath`.
This can be use to join the path, can used to add in multiple scripts to join path.

## Script Details

### Variables

- `$ReportPath`: This variable stores the path to the `Report` directory, which is created in the root directory of the script.

### Logic

1. **Join-Path**: Combines the root directory of the script (`$PSScriptRoot`) with the directory name `Report` to form the full path and assigns it to `$ReportPath`.
2. **Test-Path**: Checks if the path stored in `$assetsPath` exists.
3. **New-Item**: If the path does not exist, it creates a new directory at the path specified by `$ReportPath`.
4. **Write-Host**: Outputs a message to the console indicating that the path has been created, with the message displayed in yellow.
5. **Output**: Finally, the script outputs the value of `$ReportPath`.

## Usage

To use this script, simply run it in a PowerShell environment. Ensure that `$assetsPath` is defined before running the script.

```powershell
$ReportPath = Join-Path $PSScriptRoot Report
if (-not (Test-path $assetsPath)) {
    $null = New-Item -ItemType Directory -Path $ReportPath -Force
    Write-Host "Path created $($ReportPath)" -ForegroundColor Yellow
}
$ReportPath