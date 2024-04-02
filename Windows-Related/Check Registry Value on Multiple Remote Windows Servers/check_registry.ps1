<#	
	.NOTES
	===========================================================================
	 Created on:   	4/2/2024 4:19 PM
	 Created by:   	Amol Patil
	 Contact at:   	amolsp777@live.com
	 Contact at:   	https://github.com/amolsp777
	 Filename:     	check_registry.ps1
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>

# Define an array of server names
$servers = @("Server1", "Server2", "Server3")

# Define the registry key path
$regPath = "HKLM:SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine"  # registry key path and value name
$valueName = "RuntimeVersion" # "YourValueName"


# Loop through each server
foreach ($server in $servers) {
    # Check if server is reachable
    $isReachable = Test-Connection -ComputerName $server -Count 1 -Quiet
    if ($isReachable) {
        try {
            # Attempt to retrieve the registry value data from the remote server
            $regValue = Invoke-Command -ComputerName $server -ScriptBlock {
                param($path, $value)
                $data = Get-ItemProperty -Path "$path" -Name $value -ErrorAction Stop
                $data.$value
            } -ArgumentList $regPath, $valueName -ErrorAction Stop

            # Output the server name, registry key, and value data
            [PSCustomObject]@{
                ServerName = $server
                Active     = $true
                KeyName    = "$regPath\$valueName"
                ValueData  = $regValue
            }
        }
        catch {
            # If registry key not present, output that information
            [PSCustomObject]@{
                ServerName = $server
                Active     = $true
                KeyName    = "$regPath\$valueName"
                ValueData  = "Key not present"
            }
        }
    }
    else {
        # If server is not reachable, output that information
        [PSCustomObject]@{
            ServerName = $server
            Active     = $false
            KeyName    = $null
            ValueData  = $null
        }
    }
}