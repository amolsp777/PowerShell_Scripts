# PowerShell Log and Display Utility

- [Overview](#overview)
- [Usage](#usage)
  - [Syntax](#syntax)
  - [Parameters](#parameters)
- [Examples](#examples)
- [Notes](#notes)
- [Installation](#installation)

## Overview

This PowerShell utility, `Add-WriteHost`, allows you to log messages to a file and display them on the console with different colors based on the log level. Whether you're working on scripts or automation tasks, this utility enhances your logging capabilities by providing flexibility in customizing log messages.

## Usage

### Syntax

```powershell
Add-WriteHost [-Message] <string> [-Color <string>] [-Level <string>] [-LogFile <string>]
```
### Parameters

- `Message` (Mandatory): The message you want to log and display.
- `Color` (Optional): The text color for displaying the message on the console (default is "White").
- `Level` (Optional): The log level, which can be "Error," "Warn," or "Info" (default is "Info").
- `LogFile` (Optional): The path to a log file where messages should be stored. If not provided, the function will create a log file in the current working directory with a timestamp.

## Examples
### Example 1

```powershell
"Do something completed successfully." | Add-WriteHost
```
This example logs an informational message without specifying a log file. The message will be logged to a log file in the current working directory and displayed on the console in white.

### Example 2
```powershell
"Warning: An issue occurred!" | Add-WriteHost -Color "Yellow" -Level "Warn" -LogFile "C:\Logs\MyScript.log"
```
This example logs a warning message with a custom color and specifies a log file. The message will be logged to the specified log file in yellow and displayed on the console in yellow as well.

### Example 3
```powershell
"Error: Something went wrong!" | Add-WriteHost -Level "Error"
```
This example logs an error message with the default color and no log file. The message will be logged to a log file in the current working directory and displayed on the console in red

### Example 4
```powershell
Get-Service | Out-String | Add-WriteHost
```
This example uses the function with `Get-Service` to log service information. It retrieves a list of services and logs all service details in table format to a log file in the current working directory, displaying them on the console in white.
### Example 5
```powershell
Get-Service | ForEach-Object { "[Service Name: $($_.DisplayName)], [Status: $($_.Status)]" | Add-WriteHost }
```
This example uses the function with `Get-Service` to log service information. It retrieves a list of services and logs each service's name and status to a log file in the current working directory, displaying them on the console in white.
## Notes
- This utility provides you with the flexibility to customize log messages, colors, and log file locations.
- It is a useful tool for scripters and system administrators to enhance the readability and management of logs during PowerShell scripting and automation tasks.
- Ensure that your PowerShell execution policy allows script execution. You can check and modify the execution policy using the Set-ExecutionPolicy cmdlet if necessary.
- Enjoy using the `Add-WriteHost` utility for logging and displaying messages in your PowerShell scripts and automation tasks!

## Installation

To use the `Add-WriteHost` PowerShell utility, follow these steps:

1. Download the script or function and save it to a directory of your choice.
2. Open PowerShell or your preferred PowerShell environment.
3. Navigate to the directory where you saved the script or function.
4. Import or dot-source the script into your PowerShell session if needed. For example:
   ```powershell
   . .\Add-WriteHost.ps1
    ```
You can now use the `Add-WriteHost` function in your scripts or directly in the PowerShell console as demonstrated in the **Examples** section.

## PowerShell Function Code

```powershell
Function Add-WriteHost {
    [CmdletBinding()] 
    Param 
        ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 

        [Parameter(Mandatory=$false)] 
        [ValidateSet("Red","Yellow","Green")] 
        [string]$Color="White",

        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info",

        [Parameter(Mandatory=$false)]
        [string]$LogFile  # Added parameter for specifying the log file path
    )

    $FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
    $LevelText = $Level.ToUpper() + ':'

    $LogMessage = "$FormattedDate $LevelText $Message"

    if ($LogFile) {
        # Use the specified log file path and append data
        Add-Content -Path $LogFile -Value $LogMessage -Append
    } else {
        # Use the current working directory and create a log file with a timestamp
        $ScriptRoot = $PSScriptRoot
        if (-not $ScriptRoot) {
            $ScriptRoot = Get-Location
        }
        
        $LogFileName = Join-Path -Path $ScriptRoot -ChildPath "Log_$((Get-Date -Format 'yyyyMMdd').ToString()).log"
        Add-Content -Path $LogFileName -Value $LogMessage
    }

    switch ($Level) { 
        'Error' {
            Write-Host $LogMessage -ForegroundColor Red
        } 
        'Warn' { 
            Write-Host $LogMessage -ForegroundColor Yellow
        } 
        'Info' { 
            Write-Host $LogMessage -ForegroundColor $Color
        } 
    } 
}
