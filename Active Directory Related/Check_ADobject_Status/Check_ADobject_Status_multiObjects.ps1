# Define the object names to search for
$objectNames = @("abc", "1Test-amol", "Test-amol")  # Add as many names as needed

# Get all Domain Controllers
$domainControllers = Get-ADDomainController -Filter *



# Create an array to store results
$results = @()

# Initialize progress variables
$totalObjects = $objectNames.Count
$totalDCs = $domainControllers.Count
$currentObjectIndex = 0
$i = 0
# Check object presence for each name on each DC
foreach ($objectName in $objectNames) {
    $currentObjectIndex++   
    $currentDCIndex = 0

    foreach ($dc in $domainControllers) {

        $currentDCIndex++
        $dcName = $dc.HostName

        # Update progress
        $progressPercent = (($currentObjectIndex - 1) * $totalDCs + $currentDCIndex) / ($totalObjects * $totalDCs) * 100
        Write-Progress -Activity "Checking objects on Domain Controllers [$currentDCIndex/$totalDCs]" -Status "Processing [$currentObjectIndex\$totalObjects] $objectName on $dcName" -PercentComplete $progressPercent

      try {
        $objectCheck = Get-ADObject -Filter { samaccountname -eq $objectName } -Server $dc #-ErrorAction Stop

        if ($objectCheck) {
            $Objstatus =  "Present"
            $objtype = $objectCheck.ObjectClass
        } else {
           $Objstatus = "Not Present"
           $objtype = ""
        }
    } catch {
       # Write-Warning "Error checking $objectName on $dc $_"
        $Objstatus =  "Not Present"
    }
    

        #$status = Check-ObjectPresence -dc $dcName -objectName $objectName
        $results += [PSCustomObject]@{
            ObjectName       = $objectName
            ObjectType       = $objtype
            DomainController = $dcName
            Status           = $Objstatus
        }
    }
}

# Output the results as a table
$results | Format-Table -AutoSize
