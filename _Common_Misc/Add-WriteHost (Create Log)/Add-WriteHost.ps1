<#
.SYNOPSIS
    Logs messages to a file and displays them on the console with different colors based on the log level.

.DESCRIPTION
    The Add-WriteHost function accepts log messages and provides flexibility in logging and displaying them. It allows you to specify the log file path or use the current working directory for logging. Log messages can be displayed in different colors based on the log level (Error, Warn, Info).

.PARAMETER Message
    The message you want to log in and display.

.PARAMETER Color
    The text color for displaying the message on the console (default is "White").

.PARAMETER Level
    The log level, which can be "Error," "Warn," or "Info" (default is "Info").

.PARAMETER LogFile
    The path to a log file where messages should be stored. If not provided, the function will create a log file in the current working directory with a timestamp.

.EXAMPLE
    "Do something completed successfully." | Add-WriteHost

    This example logs an informational message without specifying a log file. The message will be logged to a log file in the current working directory and displayed on the console in white.

.EXAMPLE
    "Warning: An issue occurred!" | Add-WriteHost -Color "Yellow" -Level "Warn" -LogFile "C:\Logs\MyScript.log"

    This example logs a warning message with a custom color and specifies a log file. The message will be logged to the specified log file in yellow and displayed on the console in yellow as well.

.EXAMPLE
    "Error: Something went wrong!" | Add-WriteHost -Level "Error"

    This example logs an error message with the default color and no log file. The message will be logged to a log file in the current working directory and displayed on the console in red.

.EXAMPLE
    Get-Service | Out-String | Add-WriteHost

    This example uses the function with Get-Service to log service information. It retrieves a list of services and logs all services details in table formate to a log file in the current working directory, displaying them on the console in white.
    
.EXAMPLE
    Get-Service | ForEach-Object { "[Service Name: $($_.DisplayName)], [Status: $($_.Status)]" | Add-WriteHost }

    This example uses the function with Get-Service to log service information. It retrieves a list of services and logs each service's name and status to a log file in the current working directory, displaying them on the console in white.

#>

#region Simple Add-WriteHost Function
# It will write normal time based logs on the screen
Function Add-WriteHost {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Red", "Yellow", "Green")]
        [string]$Color = "White",
        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warn", "Info")]
        [string]$Level = "Info",
        [Parameter(Mandatory = $false)]
        [string]$LogFile # Added parameter for specifying the log file path
    )
	
    $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LevelText = '[' + $Level.ToUpper() + ']' + ':'
	
    $LogMessage = "$FormattedDate $LevelText $Message"
	
    if ($LogFile) {
        # Use the specified log file path and append data
        Add-Content -Path $LogFile -Value $LogMessage -Append
    }
    else {
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
#endregion

Add-WriteHost -Message "Testing" -Level Info 
Add-WriteHost -Message "Testing" -Level Error
Add-WriteHost -Message "Testing" -Level Warn

# $ser = Get-Service | Out-String

#Add-WriteHost -Message "$ser"

# Get-Volume | Out-String | Add-WriteHost

"Error: Something went wrong!" | Add-WriteHost -Level "Error"


# Get-Service | Out-String | Add-WriteHost
