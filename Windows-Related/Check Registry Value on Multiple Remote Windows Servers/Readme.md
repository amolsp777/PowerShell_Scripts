# Check Registry Value on Multiple Remote Windows Servers

This PowerShell script allows you to check a specific registry value on multiple remote Windows servers. It connects to each server, checks the specified registry key, and retrieves the value if present.

## Prerequisites

- Windows PowerShell installed on your local machine.
- Remote servers accessible via PowerShell remoting.

## Usage

1. Clone or download the script file (`check_registry.ps1`).
2. Modify the script variables as needed:
    - `$servers`: An array containing the names or IP addresses of the remote servers you want to check.
    - `$regPath`: The registry key path where the value is located.
    - `$valueName`: The name of the registry value you want to check.
3. Run the script in a PowerShell environment.

## Script Logic

1. The script defines an array of server names (`$servers`) and the registry key path (`$regPath`).
2. It loops through each server, attempting to retrieve the specified registry value.
3. If the server is unreachable, it displays a message indicating that.
4. If the registry key or value is not present, it displays appropriate messages.
5. If the value is present, it outputs the server name, registry key, and value data in a custom object format.

## Example

```powershell
# Define server names
$servers = @("Server1", "Server2", "Server3")

# Define the registry key path
$regPath = "HKLM:SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine"  # registry key path and value name
$valueName = "RuntimeVersion" # "YourValueName"

# Run the script
.\check_registry.ps1
```
## Notes
- Ensure that your user account has the necessary permissions to access the registry on remote servers.
- Modify the script according to your specific requirements.

