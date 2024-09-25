# Define the object name to search for
$objectName = "POC-AMOL"

# Get all Domain Controllers
$domainControllers = Get-ADDomainController -Filter *

# Function to check object presence on a DC
function Check-ObjectPresence {
    param (
        [string]$dc,
        [string]$objectName
    )
    try {
        $object = Get-ADObject -Filter { Name -eq $objectName } -Server $dc -ErrorAction Stop

        if ($object) {
            #Write-Output "Object $objectName found on $dc"
            return "Present"
        } else {
            #Write-Output "Object $objectName not found on $dc"
            return "Not Present"
        }
    } catch {
        Write-Warning "Error checking $objectName on $dc $_"
        return "Not Present"
    }
}

# Create an array to store results
$results = @()

# Check object presence on each DC
foreach ($dc in $domainControllers) {
    $dcName = $dc.HostName
    $status = Check-ObjectPresence -dc $dcName -objectName $objectName 
    $results += [PSCustomObject]@{
        DomainController = $dcName
        Status           = $status
    }
}

# Output the results as a table
$results | Format-Table -AutoSize