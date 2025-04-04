# Read server names and environment values from CSV
#$serverInstances = Import-Csv -Path "serverlist.csv"

#region Define the SQL Server instances
$serverInstances = Import-Csv -Path ($PSScriptRoot + "\SQLserverlist.csv") #| select -First 5 
Write-Host "Totatl count - $($serverInstances.count)"
#endregion Define the SQL Server instances


Function Get-CPUInfo {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $TRUE, ValueFromPipeline = $TRUE)]   
        [String] $ServerName,
        [String] $Environment
    )

    Process {
        # Get Default SQL Server instance's Edition
        $sqlconn = new-object System.Data.SqlClient.SqlConnection("server=$ServerName;Trusted_Connection=true")
        $query = "SELECT 
              SERVERPROPERTY('Edition') AS Edition, 
              SERVERPROPERTY('MachineName') AS MachineName,
              SERVERPROPERTY('IsClustered') AS IsClustered,
              SERVERPROPERTY('InstanceName') AS InstanceName,
              COUNT(name) AS DatabaseCount
          FROM 
              sys.databases
          WHERE 
              state_desc = 'ONLINE';"

        $sqlconn.Open()
        $sqlcmd = new-object System.Data.SqlClient.SqlCommand ($query, $sqlconn)
        $sqlcmd.CommandTimeout = 0
        $dr = $sqlcmd.ExecuteReader()

        while ($dr.Read()) { 
            $SQLEdition = $dr.GetValue(0)
            $MachineName = $dr.GetValue(1)
            $IsClustered = $dr.GetValue(2)
            $InstanceName = $dr.GetValue(3)
            $DatabaseCount = $dr.GetValue(4)

            # Check if InstanceName is NULL (default instance)
            if ($InstanceName -eq [System.DBNull]::Value) {
                $InstanceName = "Default"
            }
            # Convert IsClustered value to boolean
            $IsClustered = [bool]$IsClustered
        }

        $dr.Close()
        $sqlconn.Close()

        # Get processors information            
        $CPU = Get-WmiObject -ComputerName $MachineName -class Win32_Processor
        # Get Computer model information
        $OS_Info = Get-WmiObject -ComputerName $MachineName -class Win32_ComputerSystem
            
        # Reset number of cores and use count for the CPUs counting
        $CPUs = 0
        $Cores = 0
        
        foreach ($Processor in $CPU) {
            $CPUs += 1
            # Count the total number of cores         
            $Cores += $Processor.NumberOfCores
        } 
           
        $InfoRecord = New-Object -TypeName psobject -Property @{
            Server                = $ServerName
            InstanceName               = $InstanceName
            DatabaseCount               = $DatabaseCount
            Model                 = $OS_Info.Model
            CPUNumber             = $CPUs
            TotalCores            = $Cores
            Edition               = $SQLEdition
            IsClustered               = $IsClustered
            'Cores to CPUs Ratio' = $Cores / $CPUs
            Environment           = $Environment
            Resume                = if ($SQLEdition -like "Developer*") { "N/A" }
            elseif ($Cores -eq $CPUs) { "No licensing changes" }
            else { "licensing costs increase in " + $Cores / $CPUs + " times" }
        }
        Write-Output $InfoRecord
    }
}

# Array to store results
$SQLServerDetails = @()

# Loop through each SQL server
foreach ($serverInstance in $serverInstances) {
    Write-host "Working on $($serverInstance.ServerName)"
    $SQLServerDetails += Get-CPUInfo -ServerName $serverInstance.ServerName -Environment $serverInstance.Environment
}

# Export to CSV
$sqldetailsoutput = $SQLServerDetails | select Server,Environment,InstanceName, Edition,DatabaseCount,IsClustered, CPUNumber, TotalCores, 'Cores to CPUs Ratio', Model, Resume 
$sqldetailsoutput | Export-Csv -Path ($PSScriptRoot + "\output.csv") -NoTypeInformation
$sqldetailsoutput | Format-Table 


$createdDate = (get-date -Format "MMddyyyy")
$sqldetailsoutput | Out-HtmlView -FilePath ($PSScriptRoot + "\SQLserverlist_$($createdDate).html")  -Filtering -OrderMulti  -SearchPane -SearchPaneLocation bottom -SearchRegularExpression 




