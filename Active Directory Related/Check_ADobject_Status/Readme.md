# Active Directory Object Presence Checker

This PowerShell script checks if a specified Active Directory object (user, group, or computer) is present on all Domain Controllers (DCs) in your environment.

## Usage

1. **Replace** `YourObjectName` with the name of the object you want to check.
2. **Set** `$objectType` to `"User"`, `"Group"`, or `"Computer"` based on the type of object you're checking.
3. **Run** the script in a PowerShell session with the necessary permissions to query Active Directory.

## Script

```powershell
# Define the object name and type to search for
$objectName = "YourObjectName"
$objectType = "User"  # Change to "Group" or "Computer" as needed

# Get all Domain Controllers
$domainControllers = Get-ADDomainController -Filter *

# Function to check object presence on a DC
function Check-ObjectPresence {
    param (
        [string]$dc,
        [string]$objectName,
        [string]$objectType
    )
    try {
        switch ($objectType) {
            "User" {
                $object = Get-ADUser -Filter { Name -eq $objectName } -Server $dc -ErrorAction Stop
            }
            "Group" {
                $object = Get-ADGroup -Filter { Name -eq $objectName } -Server $dc -ErrorAction Stop
            }
            "Computer" {
                $object = Get-ADComputer -Filter { Name -eq $objectName } -Server $dc -ErrorAction Stop
            }
            default {
                throw "Invalid object type specified."
            }
        }
        if ($object) {
            Write-Output "Object $objectName found on $dc"
            return "Present"
        } else {
            Write-Output "Object $objectName not found on $dc"
            return "Not Present"
        }
    } catch {
        Write-Warning "Error checking $objectName on $dc: $_"
        return "Not Present"
    }
}

# Create an array to store results
$results = @()

# Check object presence on each DC
foreach ($dc in $domainControllers) {
    $dcName = $dc.HostName
    $status = Check-ObjectPresence -dc $dcName -objectName $objectName -objectType $objectType
    $results += [PSCustomObject]@{
        DomainController = $dcName
        Status           = $status
    }
}

# Output the results as a table
$results | Format-Table -AutoSize
```
## Example

To check if a user named  `JohnDoe`  is present on all Domain Controllers:

1.  Set  `$objectName`  to  `"JohnDoe"`.
2.  Set  `$objectType`  to  `"User"`.
```powershell
    $objectName = "JohnDoe"
    $objectType = "User"
```
Run the script in a PowerShell session with the necessary permissions.
## Output

The script will output a table showing each Domain Controller and whether the specified object is present or not.

```
DomainController   Status
----------------   ------
DC1                Present
DC2                Not Present
DC3                Present
...
```

## Troubleshooting

If the script reports an object as present when it is not, ensure that:
-   The object name is correctly specified.
-   The script is run with sufficient permissions.
-   The Domain Controllers are reachable and responsive.