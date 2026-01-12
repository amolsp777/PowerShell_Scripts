#@=============================================
#@ FileName: Get-ADGroupMember_NoRecursive_count.ps1
#@=============================================
#@ Script Name: Get-ADGroupMember_NoRecursive_count
#@ Created: 19/OCT/2016 
#@ Modified: $(Get-Date -Format "dd-MMM-yyyy")
#@ Author: Amol Patil
#@ Email: amolsp777@live.com
#@ Requirements: ActiveDirectory Module, PSWriteHTML Module
#@ OS: Windows Server 2008/2012/2016/2019/2022
#@ Version: 2.0
#@=============================================
#@ Purpose – To get the Members list from AD Group and generate comprehensive statistics
#@ Details – This script will Search the provided Group name and get the Users from parent group and Sub-group(If Available)
#@
#@=============================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$GroupNames,
    
    [Parameter(Mandatory = $false)]
    [string]$SearchBase,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxGroups,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [string]$WebCopyPath,
    
    [Parameter(Mandatory = $false)]
    [int]$FileRetentionDays = 60,
    
    [Parameter(Mandatory = $false)]
    [string[]]$FilterOUs = @("OU=TEAMS", "OU=SERVICES"),
    
    [Parameter(Mandatory = $false)]
    [int]$ThrottleLimit = 10,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseSequential
)

#region Module Validation
$requiredModules = @('ActiveDirectory', 'PSWriteHTML')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error "Required module '$module' is not installed. Please install it using: Install-Module -Name $module"
        exit 1
    }
    Import-Module $module -ErrorAction Stop
}
#endregion 

# Get Start Time
$startMain = Get-Date
$SCRIPT_PARENT = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Set default output path if not provided
if (-not $OutputPath) {
    $OutputPath = $SCRIPT_PARENT
}

#region File Cleanup
Write-Host "Cleaning up old files (older than $FileRetentionDays days)..." -ForegroundColor Cyan
try {
    Get-ChildItem -Path $SCRIPT_PARENT -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            (($_.Name -like "*.csv") -or ($_.Name -like "*.html")) -and 
            ($_.LastWriteTime -lt (Get-Date).AddDays(-$FileRetentionDays))
        } |
        Remove-Item -Verbose -ErrorAction SilentlyContinue
    Write-Host "File cleanup completed." -ForegroundColor Green
}
catch {
    Write-Warning "Error during file cleanup: $($_.Exception.Message)"
}
#endregion

#region Get AD Groups
Write-Host "Retrieving AD Groups..." -ForegroundColor Cyan
try {
    if ($GroupNames) {
        $Groups = $GroupNames
        Write-Host "Processing $($Groups.Count) specified group(s)." -ForegroundColor Green
    }
    elseif ($SearchBase) {
        $filter = "*"
        if ($MaxGroups) {
            $Groups = (Get-ADGroup -Filter $filter -SearchBase $SearchBase -ErrorAction Stop | 
                      Select-Object -First $MaxGroups -ExpandProperty Name)
        }
        else {
            $Groups = (Get-ADGroup -Filter $filter -SearchBase $SearchBase -ErrorAction Stop | 
                      Select-Object -ExpandProperty Name)
        }
        Write-Host "Retrieved $($Groups.Count) group(s) from SearchBase: $SearchBase" -ForegroundColor Green
    }
    else {
        if ($MaxGroups) {
            $Groups = (Get-ADGroup -Filter * -ErrorAction Stop | 
                      Select-Object -First $MaxGroups -ExpandProperty Name)
        }
        else {
            $Groups = (Get-ADGroup -Filter * -ErrorAction Stop | 
                      Select-Object -ExpandProperty Name)
        }
        Write-Host "Retrieved $($Groups.Count) group(s) from entire domain." -ForegroundColor Green
    }
    
    if ($Groups.Count -eq 0) {
        Write-Error "No groups found to process."
        exit 1
    }
}
catch {
    Write-Error "Failed to retrieve AD Groups: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Process Groups (Parallel)
$Date = Get-Date -Format "dd-MM-yyyy"
$output = Join-Path $OutputPath "GroupMembers_List_$Date.csv"
$errorCount = 0

# Check PowerShell version for parallel processing
$PSVersion = $PSVersionTable.PSVersion.Major
$ResultOut = @()

# Use sequential if explicitly requested or if PowerShell version is less than 7
if ($UseSequential -or $PSVersion -lt 7) {
    # Sequential processing with progress
    Write-Host "Processing $($Groups.Count) groups sequentially..." -ForegroundColor Cyan
    $i = 0
    foreach ($Group in $Groups) {
        $i++
        Write-Progress -Activity "Processing AD Groups" -Status "Processing: $Group ($i of $($Groups.Count))" -PercentComplete (($i / $Groups.Count) * 100)
        
        try {
            # Get group properties including Members (direct members only)
            $ADgrp = Get-ADGroup -Identity $Group -Properties Description, Info, ManagedBy, whenCreated, whenChanged, GroupCategory, GroupScope, Members -ErrorAction Stop
            
            # Get direct members only (non-recursive) from the Members property
            # This ensures we only get direct members, not recursive members
            $members = @()
            if ($ADgrp.Members -and $ADgrp.Members.Count -gt 0) {
                foreach ($memberDN in $ADgrp.Members) {
                    try {
                        $memberObj = Get-ADObject -Identity $memberDN -Properties Name, ObjectClass -ErrorAction Stop
                        if ($memberObj) {
                            $members += $memberObj | Select-Object Name, ObjectClass
                        }
                    }
                    catch {
                        # Skip objects that can't be resolved (deleted objects, etc.)
                        continue
                    }
                }
            }
            
            # Calculate member statistics
            $memCount = if ($members) { $members.Count } else { 0 }
            $MemNames1 = if ($members) { ($members.Name) -join ",`n" } else { "" }
            $membersType = if ($members) { ($members.ObjectClass | Sort-Object -Unique) -join ",`n" } else { "" }
            
            # Count member types
            $userCount = ($members | Where-Object { $_.ObjectClass -eq "user" }).Count
            $groupCount = ($members | Where-Object { $_.ObjectClass -eq "group" }).Count
            $computerCount = ($members | Where-Object { $_.ObjectClass -eq "computer" }).Count
            $contactCount = ($members | Where-Object { $_.ObjectClass -eq "contact" }).Count
            
            # Get nested groups
            $memgrpnmS = $members | Where-Object { $_.ObjectClass -eq "Group" }
            $memASGrpName = if ($memgrpnmS) { ($memgrpnmS.Name) -join ",`n" } else { "" }
            $nestedGroupCount = if ($memgrpnmS) { $memgrpnmS.Count } else { 0 }
            
            # Extract OU from DistinguishedName
            $ouPath = ""
            if ($ADgrp.DistinguishedName) {
                $dnParts = $ADgrp.DistinguishedName -split ','
                $ouParts = $dnParts | Where-Object { $_ -like "OU=*" }
                $ouPath = if ($ouParts) { ($ouParts -join ',') } else { "" }
            }
            
            # Create result object
            $Results = [PSCustomObject]@{
                Group                = $Group
                MembersCount         = $memCount
                UserCount            = $userCount
                GroupCount           = $groupCount
                ComputerCount        = $computerCount
                ContactCount         = $contactCount
                NestedGroupCount     = $nestedGroupCount
                MembersName          = $MemNames1
                MembersType          = $membersType
                MembersAsGroup       = $memASGrpName
                Info                 = $ADgrp.Info
                Description          = $ADgrp.Description
                HasDescription       = [bool]$ADgrp.Description
                GroupCategory        = $ADgrp.GroupCategory
                GroupScope           = $ADgrp.GroupScope
                ManagedBy            = $ADgrp.ManagedBy
                HasManager           = [bool]$ADgrp.ManagedBy
                DistinguishedName    = $ADgrp.DistinguishedName
                OUPath               = $ouPath
                whenCreated          = $ADgrp.whenCreated
                whenChanged          = $ADgrp.whenChanged
                DaysSinceCreated     = if ($ADgrp.whenCreated) { ((Get-Date) - $ADgrp.whenCreated).Days } else { $null }
                DaysSinceModified    = if ($ADgrp.whenChanged) { ((Get-Date) - $ADgrp.whenChanged).Days } else { $null }
            }
            
            $ResultOut += $Results
        }
        catch {
            $errorCount++
            Write-Warning "Error processing group '$Group': $($_.Exception.Message)"
            # Add error record
            $ErrorResults = [PSCustomObject]@{
                Group                = $Group
                MembersCount         = 0
                UserCount            = 0
                GroupCount           = 0
                ComputerCount        = 0
                ContactCount         = 0
                NestedGroupCount     = 0
                MembersName          = "Error: $($_.Exception.Message)"
                MembersType          = ""
                MembersAsGroup       = ""
                Info                 = ""
                Description          = ""
                HasDescription       = $false
                GroupCategory        = ""
                GroupScope           = ""
                ManagedBy            = ""
                HasManager           = $false
                DistinguishedName    = ""
                OUPath               = ""
                whenCreated          = ""
                whenChanged          = ""
                DaysSinceCreated     = $null
                DaysSinceModified    = $null
            }
            $ResultOut += $ErrorResults
        }
    }
    Write-Progress -Activity "Processing AD Groups" -Completed
}
elseif ($PSVersion -ge 7) {
    Write-Host "Processing $($Groups.Count) groups in parallel (ThrottleLimit: $ThrottleLimit)..." -ForegroundColor Cyan
    # PowerShell 7+ - Use ForEach-Object -Parallel with job for progress tracking
    Write-Host "Starting parallel processing..." -ForegroundColor Yellow
    
    $job = $Groups | ForEach-Object -Parallel {
        $GroupName = $_
        
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
        
        $result = $null
        $errorMsg = $null
        
        try {
            # Get group properties including Members (direct members only)
            $ADgrp = Get-ADGroup -Identity $GroupName -Properties Description, Info, ManagedBy, whenCreated, whenChanged, GroupCategory, GroupScope, Members -ErrorAction Stop
            
            # Get direct members only (non-recursive) from the Members property
            # This ensures we only get direct members, not recursive members
            $members = @()
            if ($ADgrp.Members -and $ADgrp.Members.Count -gt 0) {
                foreach ($memberDN in $ADgrp.Members) {
                    try {
                        $memberObj = Get-ADObject -Identity $memberDN -Properties Name, ObjectClass -ErrorAction Stop
                        if ($memberObj) {
                            $members += $memberObj | Select-Object Name, ObjectClass
                        }
                    }
                    catch {
                        # Skip objects that can't be resolved (deleted objects, etc.)
                        continue
                    }
                }
            }
            
            # Calculate member statistics
            $memCount = if ($members) { $members.Count } else { 0 }
            $MemNames1 = if ($members) { ($members.Name) -join ",`n" } else { "" }
            $membersType = if ($members) { ($members.ObjectClass | Sort-Object -Unique) -join ",`n" } else { "" }
            
            # Count member types
            $userCount = ($members | Where-Object { $_.ObjectClass -eq "user" }).Count
            $groupCount = ($members | Where-Object { $_.ObjectClass -eq "group" }).Count
            $computerCount = ($members | Where-Object { $_.ObjectClass -eq "computer" }).Count
            $contactCount = ($members | Where-Object { $_.ObjectClass -eq "contact" }).Count
            
            # Get nested groups
            $memgrpnmS = $members | Where-Object { $_.ObjectClass -eq "Group" }
            $memASGrpName = if ($memgrpnmS) { ($memgrpnmS.Name) -join ",`n" } else { "" }
            $nestedGroupCount = if ($memgrpnmS) { $memgrpnmS.Count } else { 0 }
            
            # Extract OU from DistinguishedName
            $ouPath = ""
            if ($ADgrp.DistinguishedName) {
                $dnParts = $ADgrp.DistinguishedName -split ','
                $ouParts = $dnParts | Where-Object { $_ -like "OU=*" }
                $ouPath = if ($ouParts) { ($ouParts -join ',') } else { "" }
            }
            
            # Create result object
            $result = [PSCustomObject]@{
                Group                = $GroupName
                MembersCount         = $memCount
                UserCount            = $userCount
                GroupCount           = $groupCount
                ComputerCount        = $computerCount
                ContactCount         = $contactCount
                NestedGroupCount     = $nestedGroupCount
                MembersName          = $MemNames1
                MembersType          = $membersType
                MembersAsGroup       = $memASGrpName
                Info                 = $ADgrp.Info
                Description          = $ADgrp.Description
                HasDescription       = [bool]$ADgrp.Description
                GroupCategory        = $ADgrp.GroupCategory
                GroupScope           = $ADgrp.GroupScope
                ManagedBy            = $ADgrp.ManagedBy
                HasManager           = [bool]$ADgrp.ManagedBy
                DistinguishedName    = $ADgrp.DistinguishedName
                OUPath               = $ouPath
                whenCreated          = $ADgrp.whenCreated
                whenChanged          = $ADgrp.whenChanged
                DaysSinceCreated     = if ($ADgrp.whenCreated) { ((Get-Date) - $ADgrp.whenCreated).Days } else { $null }
                DaysSinceModified    = if ($ADgrp.whenChanged) { ((Get-Date) - $ADgrp.whenChanged).Days } else { $null }
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            # Add error record (use 0 instead of "ERROR" for numeric fields)
            $result = [PSCustomObject]@{
                Group                = $GroupName
                MembersCount         = 0
                UserCount            = 0
                GroupCount           = 0
                ComputerCount        = 0
                ContactCount         = 0
                NestedGroupCount     = 0
                MembersName          = "Error: $errorMsg"
                MembersType          = ""
                MembersAsGroup       = ""
                Info                 = ""
                Description          = ""
                HasDescription       = $false
                GroupCategory        = ""
                GroupScope           = ""
                ManagedBy            = ""
                HasManager           = $false
                DistinguishedName    = ""
                OUPath               = ""
                whenCreated          = ""
                whenChanged          = ""
                DaysSinceCreated     = $null
                DaysSinceModified    = $null
            }
        }
        
        return @{
            Result = $result
            Error = $errorMsg
        }
    } -ThrottleLimit $ThrottleLimit -AsJob
    
    # Monitor job progress with timeout
    $completed = 0
    $total = $Groups.Count
    $startTime = Get-Date
    $timeoutSeconds = 3600  # 1 hour timeout
    Write-Host "Job started. Monitoring progress (timeout: $timeoutSeconds seconds)..." -ForegroundColor Yellow
    
    while (($job.State -eq 'Running' -or $job.State -eq 'NotStarted') -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
        $completed = ($job.ChildJobs | Where-Object { $_.State -eq 'Completed' }).Count
        $percent = if ($total -gt 0) { [math]::Round(($completed / $total) * 100, 1) } else { 0 }
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
        Write-Progress -Activity "Processing AD Groups (Parallel)" -Status "Completed: $completed of $total ($percent%) - Elapsed: $elapsed seconds" -PercentComplete $percent
        Start-Sleep -Milliseconds 1000
    }
    
    $elapsedTime = ((Get-Date) - $startTime).TotalSeconds
    if ($elapsedTime -ge $timeoutSeconds) {
        Write-Warning "Parallel processing timed out after $timeoutSeconds seconds. Stopping job..."
        $job | Stop-Job
        $job | Remove-Job
        Write-Error "Parallel processing failed. Consider using -UseSequential parameter."
        exit 1
    }
    
    Write-Host "`nCollecting results..." -ForegroundColor Yellow
    try {
        $results = $job | Receive-Job -Wait -ErrorAction Stop
        $job | Remove-Job
        
        Write-Host "Processing $($results.Count) results..." -ForegroundColor Yellow
        foreach ($r in $results) {
            if ($r -and $r.Error) {
                $errorCount++
                Write-Warning "Error processing group '$($r.Result.Group)': $($r.Error)"
            }
            if ($r -and $r.Result) {
                $ResultOut += $r.Result
            }
        }
    }
    catch {
        Write-Error "Failed to collect results from parallel job: $($_.Exception.Message)"
        Write-Warning "Consider using -UseSequential parameter for more reliable processing."
        exit 1
    }
}
else {
    # PowerShell 5.1 - Use Runspaces for parallel processing
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit)
    $runspacePool.Open()
    $jobs = New-Object System.Collections.ArrayList
    $counter = 0
    
    # Create script block for runspaces
    $scriptBlock = {
        param($GroupName)
        
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
        
        $result = $null
        $errorMsg = $null
        
        try {
            # Get group properties including Members (direct members only)
            $ADgrp = Get-ADGroup -Identity $GroupName -Properties Description, Info, ManagedBy, whenCreated, whenChanged, GroupCategory, GroupScope, Members -ErrorAction Stop
            
            # Get direct members only (non-recursive) from the Members property
            # This ensures we only get direct members, not recursive members
            $members = @()
            if ($ADgrp.Members -and $ADgrp.Members.Count -gt 0) {
                foreach ($memberDN in $ADgrp.Members) {
                    try {
                        $memberObj = Get-ADObject -Identity $memberDN -Properties Name, ObjectClass -ErrorAction Stop
                        if ($memberObj) {
                            $members += $memberObj | Select-Object Name, ObjectClass
                        }
                    }
                    catch {
                        # Skip objects that can't be resolved (deleted objects, etc.)
                        continue
                    }
                }
            }
            
            # Calculate member statistics
            $memCount = if ($members) { $members.Count } else { 0 }
            $MemNames1 = if ($members) { ($members.Name) -join ",`n" } else { "" }
            $membersType = if ($members) { ($members.ObjectClass | Sort-Object -Unique) -join ",`n" } else { "" }
            
            # Count member types
            $userCount = ($members | Where-Object { $_.ObjectClass -eq "user" }).Count
            $groupCount = ($members | Where-Object { $_.ObjectClass -eq "group" }).Count
            $computerCount = ($members | Where-Object { $_.ObjectClass -eq "computer" }).Count
            $contactCount = ($members | Where-Object { $_.ObjectClass -eq "contact" }).Count
            
            # Get nested groups
            $memgrpnmS = $members | Where-Object { $_.ObjectClass -eq "Group" }
            $memASGrpName = if ($memgrpnmS) { ($memgrpnmS.Name) -join ",`n" } else { "" }
            $nestedGroupCount = if ($memgrpnmS) { $memgrpnmS.Count } else { 0 }
            
            # Extract OU from DistinguishedName
            $ouPath = ""
            if ($ADgrp.DistinguishedName) {
                $dnParts = $ADgrp.DistinguishedName -split ','
                $ouParts = $dnParts | Where-Object { $_ -like "OU=*" }
                $ouPath = if ($ouParts) { ($ouParts -join ',') } else { "" }
            }
            
            # Create result object
            $result = [PSCustomObject]@{
                Group                = $GroupName
                MembersCount         = $memCount
                UserCount            = $userCount
                GroupCount           = $groupCount
                ComputerCount        = $computerCount
                ContactCount         = $contactCount
                NestedGroupCount     = $nestedGroupCount
                MembersName          = $MemNames1
                MembersType          = $membersType
                MembersAsGroup       = $memASGrpName
                Info                 = $ADgrp.Info
                Description          = $ADgrp.Description
                HasDescription       = [bool]$ADgrp.Description
                GroupCategory        = $ADgrp.GroupCategory
                GroupScope           = $ADgrp.GroupScope
                ManagedBy            = $ADgrp.ManagedBy
                HasManager           = [bool]$ADgrp.ManagedBy
                DistinguishedName    = $ADgrp.DistinguishedName
                OUPath               = $ouPath
                whenCreated          = $ADgrp.whenCreated
                whenChanged          = $ADgrp.whenChanged
                DaysSinceCreated     = if ($ADgrp.whenCreated) { ((Get-Date) - $ADgrp.whenCreated).Days } else { $null }
                DaysSinceModified    = if ($ADgrp.whenChanged) { ((Get-Date) - $ADgrp.whenChanged).Days } else { $null }
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            # Add error record (use 0 instead of "ERROR" for numeric fields)
            $result = [PSCustomObject]@{
                Group                = $GroupName
                MembersCount         = 0
                UserCount            = 0
                GroupCount           = 0
                ComputerCount        = 0
                ContactCount         = 0
                NestedGroupCount     = 0
                MembersName          = "Error: $errorMsg"
                MembersType          = ""
                MembersAsGroup       = ""
                Info                 = ""
                Description          = ""
                HasDescription       = $false
                GroupCategory        = ""
                GroupScope           = ""
                ManagedBy            = ""
                HasManager           = $false
                DistinguishedName    = ""
                OUPath               = ""
                whenCreated          = ""
                whenChanged          = ""
                DaysSinceCreated     = $null
                DaysSinceModified    = $null
            }
        }
        
        return @{
            Result = $result
            Error = $errorMsg
        }
    }
    
    foreach ($Group in $Groups) {
        $counter++
        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $runspacePool
        [void]$ps.AddScript($scriptBlock).AddArgument($Group)
        
        $null = $jobs.Add([PSCustomObject]@{
            PowerShell = $ps
            Handle = $ps.BeginInvoke()
            Group = $Group
            Index = $counter
        })
    }
    
    # Process results with progress
    $completed = 0
    while ($jobs.Count -gt 0) {
        foreach ($job in $jobs.ToArray()) {
            if ($job.Handle.IsCompleted) {
                try {
                    $result = $job.PowerShell.EndInvoke($job.Handle)
                    if ($result.Error) {
                        $errorCount++
                        Write-Warning "Error processing group '$($result.Result.Group)': $($result.Error)"
                    }
                    $ResultOut += $result.Result
                    $completed++
                    Write-Progress -Activity "Processing AD Groups" -Status "Completed: $completed of $($Groups.Count)" -PercentComplete (($completed / $Groups.Count) * 100)
                }
                catch {
                    $errorCount++
                    Write-Warning "Error retrieving result for group '$($job.Group)': $($_.Exception.Message)"
                }
                finally {
                    $job.PowerShell.Dispose()
                    $null = $jobs.Remove($job)
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
}

Write-Progress -Activity "Processing AD Groups" -Completed
Write-Host "`nProcessing completed. Processed: $($ResultOut.Count) groups, Errors: $errorCount" -ForegroundColor Green
#endregion

#region Export CSV
try {
    $ResultOut | Export-Csv -NoTypeInformation -Path $output -Encoding UTF8
    Write-Host "CSV exported to: $output" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export CSV: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Generate Statistics
Write-Host "Generating statistics..." -ForegroundColor Cyan
$importData = Import-Csv $output
$outputfileHTML = Join-Path $OutputPath "AD_Groups_List_$Date.html"

#region Basic Statistics
$totalGroups = $importData.Count
$groupsWithMembers = ($importData | Where-Object { 
    $val = $_.MembersCount
    $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
}).Count
$groupsWithoutMembers = ($importData | Where-Object { 
    $val = $_.MembersCount
    $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -le 0 
}).Count
$totalMembers = ($importData | Where-Object { 
    $val = $_.MembersCount
    $val -ne "" -and $val -notlike "*ERROR*"
} | Measure-Object -Property { [int]$_.MembersCount } -Sum).Sum
$avgMembersPerGroup = if ($groupsWithMembers -gt 0) { [math]::Round($totalMembers / $groupsWithMembers, 2) } else { 0 }
$totalUsers = ($importData | Where-Object { 
    $val = $_.UserCount
    $val -ne "" -and $val -notlike "*ERROR*"
} | Measure-Object -Property { [int]$_.UserCount } -Sum).Sum
$totalNestedGroups = ($importData | Where-Object { 
    $val = $_.NestedGroupCount
    $val -ne "" -and $val -notlike "*ERROR*"
} | Measure-Object -Property { [int]$_.NestedGroupCount } -Sum).Sum
$groupsWithDescription = ($importData | Where-Object { $_.HasDescription -eq "True" }).Count
$groupsWithManager = ($importData | Where-Object { $_.HasManager -eq "True" }).Count
$totalComputers = ($importData | Where-Object { 
    $val = $_.ComputerCount
    $val -ne "" -and $val -notlike "*ERROR*"
} | Measure-Object -Property { [int]$_.ComputerCount } -Sum).Sum
$totalContacts = ($importData | Where-Object { 
    $val = $_.ContactCount
    $val -ne "" -and $val -notlike "*ERROR*"
} | Measure-Object -Property { [int]$_.ContactCount } -Sum).Sum
$groupsWithNestedGroups = ($importData | Where-Object { 
    $val = $_.NestedGroupCount
    $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
}).Count
$groupsWithComputers = ($importData | Where-Object { 
    $val = $_.ComputerCount
    $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
}).Count
$groupsWithContacts = ($importData | Where-Object { 
    $val = $_.ContactCount
    $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
}).Count
#endregion

#region Group Scopes & Categories
$GroupScopes = $importData | Where-Object { $_.GroupScope } | 
               Group-Object GroupScope | 
               Select-Object @{
    Label = "Name"
    Expression = { if ($_.Name) { $_.Name } else { "[No Type]" } }
               }, @{
                   N = "Total Count"
                   E = { $_.Count }
               } | 
               Sort-Object 'Total Count' -Descending

$GroupCategory = $importData | Where-Object { $_.GroupCategory } | 
                 Group-Object GroupCategory | 
                 Select-Object @{
    Label = "Name"
    Expression = { if ($_.Name) { $_.Name } else { "[No Type]" } }
                 }, @{
                     N = "Total Count"
                     E = { $_.Count }
                 } | 
                 Sort-Object 'Total Count' -Descending
#endregion

#region Top Groups by Member Count
$TopGroupsByMembers = $importData | 
    Where-Object { 
        $val = $_.MembersCount
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
    } | 
    Sort-Object { [int]$_.MembersCount } -Descending | 
    Select-Object -First 20 Group, MembersCount, UserCount, GroupCount, ComputerCount, NestedGroupCount, DistinguishedName
#endregion

#region Groups with Most Nested Groups
$TopGroupsByNested = $importData | 
    Where-Object { 
        $val = $_.NestedGroupCount
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
    } | 
    Sort-Object { [int]$_.NestedGroupCount } -Descending | 
    Select-Object -First 20 Group, NestedGroupCount, MembersCount, DistinguishedName
#endregion

#region Groups by OU Distribution
$GroupsByOU = $importData | 
    Where-Object { $_.OUPath } | 
    Group-Object OUPath | 
    Select-Object @{
        Label = "OU Path"
        Expression = { $_.Name }
    }, @{
        N = "Group Count"
        E = { $_.Count }
    }, @{
        N = "Total Members"
        E = { 
            ($_.Group | Where-Object { 
                $val = $_.MembersCount
                $val -ne "" -and $val -notlike "*ERROR*"
            } | Measure-Object -Property { [int]$_.MembersCount } -Sum).Sum 
        }
    } | 
    Sort-Object 'Group Count' -Descending | 
    Select-Object -First 30
#endregion

#region Member Type Distribution
$MemberTypeStats = @(
    [PSCustomObject]@{ Type = "Users"; Count = $totalUsers }
    [PSCustomObject]@{ Type = "Groups"; Count = $totalNestedGroups }
    [PSCustomObject]@{ 
        Type = "Computers"; 
        Count = ($importData | Where-Object { 
            $val = $_.ComputerCount
            $val -ne "" -and $val -notlike "*ERROR*"
        } | Measure-Object -Property { [int]$_.ComputerCount } -Sum).Sum 
    }
    [PSCustomObject]@{ 
        Type = "Contacts"; 
        Count = ($importData | Where-Object { 
            $val = $_.ContactCount
            $val -ne "" -and $val -notlike "*ERROR*"
        } | Measure-Object -Property { [int]$_.ContactCount } -Sum).Sum 
    }
)
#endregion

#region Groups Without Members by OU
$NoMembersByOU = @()
foreach ($ouFilter in $FilterOUs) {
    $ouGroups = $importData | 
        Where-Object { 
            $memCount = $_.MembersCount
            ($memCount -ne "" -and $memCount -notlike "*ERROR*" -and [int]$memCount -le 0) -and 
            ($_.DistinguishedName -like "*$ouFilter*")
        } | 
        Select-Object Group, MembersCount, GroupCategory, GroupScope, DistinguishedName, OUPath
    
    if ($ouGroups) {
        $NoMembersByOU += [PSCustomObject]@{
            OU = $ouFilter
            Groups = $ouGroups
            Count = $ouGroups.Count
        }
    }
}
#endregion

#region Groups Recently Modified (Last 30 days)
$RecentModified = $importData | 
    Where-Object { 
        $val = $_.DaysSinceModified
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -le 30 
    } | 
    Sort-Object { [int]$_.DaysSinceModified } | 
    Select-Object Group, DaysSinceModified, MembersCount, whenChanged, DistinguishedName | 
    Select-Object -First 30
#endregion

#region Groups Recently Created (Last 90 days)
$RecentCreated = $importData | 
    Where-Object { 
        $val = $_.DaysSinceCreated
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -le 90 
    } | 
    Sort-Object { [int]$_.DaysSinceCreated } | 
    Select-Object Group, DaysSinceCreated, MembersCount, whenCreated, DistinguishedName | 
    Select-Object -First 30
#endregion

#region Groups Without Description
$GroupsNoDescription = $importData | 
    Where-Object { $_.HasDescription -ne "True" -or -not $_.Description } | 
    Select-Object Group, MembersCount, DistinguishedName | 
    Sort-Object Group | 
    Select-Object -First 50
#endregion

#region Groups Without Manager
$GroupsNoManager = $importData | 
    Where-Object { $_.HasManager -ne "True" -or -not $_.ManagedBy } | 
    Select-Object Group, MembersCount, DistinguishedName | 
    Sort-Object Group | 
    Select-Object -First 50
#endregion

#region Groups by Age (Creation Date)
$GroupsByAge = $importData | 
    Where-Object { 
        $val = $_.DaysSinceCreated
        $val -ne "" -and $val -notlike "*ERROR*"
    } | 
    Group-Object {
        $age = [int]$_.DaysSinceCreated
        if ($age -le 30) { "0-30 days" }
        elseif ($age -le 90) { "31-90 days" }
        elseif ($age -le 180) { "91-180 days" }
        elseif ($age -le 365) { "181-365 days" }
        elseif ($age -le 730) { "1-2 years" }
        elseif ($age -le 1095) { "2-3 years" }
        else { "3+ years" }
    } | 
    Select-Object @{
        Label = "Age Range"
        Expression = { $_.Name }
    }, @{
        N = "Count"
        E = { $_.Count }
    } | 
    Sort-Object 'Count' -Descending

# Calculate average age of groups
$groupsWithAge = $importData | Where-Object { 
    $val = $_.DaysSinceCreated
    $val -ne "" -and $val -notlike "*ERROR*"
}
$avgGroupAge = if ($groupsWithAge.Count -gt 0) { 
    [math]::Round(($groupsWithAge | Measure-Object -Property { [int]$_.DaysSinceCreated } -Average).Average, 0) 
} else { 0 }
$avgGroupAgeYears = [math]::Round($avgGroupAge / 365, 1)
#endregion

#region Top 10 Oldest Groups
$TopOldestGroups = $importData | 
    Where-Object { 
        $val = $_.DaysSinceCreated
        $val -ne "" -and $val -notlike "*ERROR*"
    } | 
    Sort-Object { [int]$_.DaysSinceCreated } -Descending | 
    Select-Object -First 10 Group, DaysSinceCreated, whenCreated, MembersCount, GroupCategory, GroupScope, DistinguishedName, Description |
    Select-Object @{
        Label = "Group"
        Expression = { $_.Group }
    }, @{
        Label = "Age (Days)"
        Expression = { [int]$_.DaysSinceCreated }
    }, @{
        Label = "Age (Years)"
        Expression = { [math]::Round([int]$_.DaysSinceCreated / 365, 1) }
    }, @{
        Label = "Created Date"
        Expression = { $_.whenCreated }
    }, @{
        Label = "Members Count"
        Expression = { [int]$_.MembersCount }
    }, @{
        Label = "Category"
        Expression = { $_.GroupCategory }
    }, @{
        Label = "Scope"
        Expression = { $_.GroupScope }
    }, @{
        Label = "Distinguished Name"
        Expression = { $_.DistinguishedName }
    }, @{
        Label = "Description"
        Expression = { $_.Description }
    }
#endregion

#region Groups by Modification Date Ranges
$GroupsByModificationAge = $importData | 
    Where-Object { 
        $val = $_.DaysSinceModified
        $val -ne "" -and $val -notlike "*ERROR*"
    } | 
    Group-Object {
        $age = [int]$_.DaysSinceModified
        if ($age -le 7) { "Last 7 days" }
        elseif ($age -le 30) { "8-30 days" }
        elseif ($age -le 90) { "31-90 days" }
        elseif ($age -le 180) { "91-180 days" }
        elseif ($age -le 365) { "181-365 days" }
        elseif ($age -le 730) { "1-2 years" }
        else { "2+ years" }
    } | 
    Select-Object @{
        Label = "Modification Range"
        Expression = { $_.Name }
    }, @{
        N = "Count"
        E = { $_.Count }
    } | 
    Sort-Object 'Count' -Descending
#endregion

#region Groups with Most Computers
$TopGroupsByComputers = $importData | 
    Where-Object { 
        $val = $_.ComputerCount
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
    } | 
    Sort-Object { [int]$_.ComputerCount } -Descending | 
    Select-Object -First 10 Group, ComputerCount, MembersCount, DistinguishedName
#endregion

#region Groups with Most Contacts
$TopGroupsByContacts = $importData | 
    Where-Object { 
        $val = $_.ContactCount
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 0 
    } | 
    Sort-Object { [int]$_.ContactCount } -Descending | 
    Select-Object -First 10 Group, ContactCount, MembersCount, DistinguishedName
#endregion

#region Groups by Scope and Category Combination
$GroupsByScopeCategory = $importData | 
    Where-Object { $_.GroupScope -and $_.GroupCategory } | 
    Group-Object @{
        Expression = { "$($_.GroupScope) - $($_.GroupCategory)" }
    } | 
    Select-Object @{
        Label = "Scope - Category"
        Expression = { $_.Name }
    }, @{
        N = "Count"
        E = { $_.Count }
    } | 
    Sort-Object 'Count' -Descending | 
    Select-Object -First 15
#endregion

#region Groups Not Modified in Last Year
$GroupsNotModifiedYear = $importData | 
    Where-Object { 
        $val = $_.DaysSinceModified
        $val -ne "" -and $val -notlike "*ERROR*" -and [int]$val -gt 365 
    } | 
    Sort-Object { [int]$_.DaysSinceModified } -Descending | 
    Select-Object Group, DaysSinceModified, whenChanged, MembersCount, DistinguishedName | 
    Select-Object -First 30
#endregion

#region Groups Created vs Modified Analysis
$groupsNeverModified = ($importData | Where-Object { 
    $created = $_.DaysSinceCreated
    $modified = $_.DaysSinceModified
    $created -ne "" -and $modified -ne "" -and 
    [int]$created -eq [int]$modified
}).Count

$groupsModifiedAfterCreation = ($importData | Where-Object { 
    $created = $_.DaysSinceCreated
    $modified = $_.DaysSinceModified
    $created -ne "" -and $modified -ne "" -and 
    [int]$modified -lt [int]$created
}).Count
#endregion

#endregion

#region Generate HTML Dashboard
Write-Host "Generating HTML dashboard..." -ForegroundColor Cyan
try {
    Remove-Item -Path (Join-Path $OutputPath "AD_Groups_List_*") -ErrorAction SilentlyContinue
    
    Dashboard -Name 'Active Directory Groups Report' -FilePath $outputfileHTML {
        Tab -Name 'Dashboard' {
            New-HTMLSection -HeaderTextSize 12 -HeaderText "Data collected $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -HeaderTextAlignment left -BackgroundColor White -HeaderTextColor Black -HeaderBackGroundColor White {}
            
            # Key Metrics Section
            Section -Name 'Key Metrics' -Collapsable -HeaderBackGroundColor Teal -AlignContent center {
                Panel {
                    New-HTMLPanel {
                        New-HTMLText -Text "Total Groups: $totalGroups" -FontSize 16 -FontWeight bold -Color DarkBlue
                        New-HTMLText -Text "Groups with Members: $groupsWithMembers" -FontSize 14 -Color Green
                        New-HTMLText -Text "Groups without Members: $groupsWithoutMembers" -FontSize 14 -Color Red
                        New-HTMLText -Text "Total Members (All Groups): $totalMembers" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Average Members per Group: $avgMembersPerGroup" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Total Users: $totalUsers" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Total Computers: $totalComputers" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Total Contacts: $totalContacts" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Total Nested Groups: $totalNestedGroups" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups with Nested Groups: $groupsWithNestedGroups" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups with Computers: $groupsWithComputers" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups with Contacts: $groupsWithContacts" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Average Group Age: $avgGroupAge days ($avgGroupAgeYears years)" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups with Description: $groupsWithDescription" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups with Manager: $groupsWithManager" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups Never Modified: $groupsNeverModified" -FontSize 14 -Color DarkBlue
                        New-HTMLText -Text "Groups Modified After Creation: $groupsModifiedAfterCreation" -FontSize 14 -Color DarkBlue
                    }
                }
            }
            
            # Group Summary Section
            Section -Name 'Group Summary' -Collapsable -HeaderBackGroundColor Astral -AlignContent center {
                if ($GroupScopes -and $GroupScopes.Count -gt 0) {
                    Panel {
                        $Data1 = @($GroupScopes.'Total Count' | Where-Object { $_ -ne $null })
                        $DataNames1 = @($GroupScopes.Name | Where-Object { $_ -ne $null -and $_ -ne "" })
                        if ($Data1.Count -gt 0 -and $DataNames1.Count -gt 0) {
                            Chart -Title 'Group Scopes Distribution' -TitleAlignment center -Gradient -SubTitle "Total Groups - $totalGroups" -SubTitleColor Blue -SubTitleFontSize 14 {
                                ChartBarOptions -Type bar -DataLabelsOffsetX 15
                                ChartLegend -Name 'Total'
                                for ($i = 0; $i -lt $Data1.Count; $i++) {
                                    if ($i -lt $DataNames1.Count -and $DataNames1[$i]) {
                                        ChartBar -Name $DataNames1[$i] -Value $Data1[$i]
                                    }
                                }
                            }
                        }
                    }
                }
                
                if ($GroupCategory -and $GroupCategory.Count -gt 0) {
                    Panel {
                        $Data2 = @($GroupCategory.'Total Count' | Where-Object { $_ -ne $null })
                        $DataNames2 = @($GroupCategory.Name | Where-Object { $_ -ne $null -and $_ -ne "" })
                        if ($Data2.Count -gt 0 -and $DataNames2.Count -gt 0) {
                            Chart -Title 'Group Category Distribution' -TitleAlignment center -Gradient -SubTitle "Total Groups - $totalGroups" -SubTitleColor Blue -SubTitleFontSize 14 {
                                ChartBarOptions -Type bar -DataLabelsOffsetX 15
                                ChartLegend -Name 'Total'
                                for ($i = 0; $i -lt $Data2.Count; $i++) {
                                    if ($i -lt $DataNames2.Count -and $DataNames2[$i]) {
                                        ChartBar -Name $DataNames2[$i] -Value $Data2[$i]
                                    }
                                }
                            }
                        }
                    }
                }
                
                if ($MemberTypeStats -and $MemberTypeStats.Count -gt 0) {
                    Panel {
                        $Data3 = @($MemberTypeStats | ForEach-Object { $_.Count } | Where-Object { $_ -ne $null })
                        $DataNames3 = @($MemberTypeStats | ForEach-Object { $_.Type } | Where-Object { $_ -ne $null -and $_ -ne "" })
                        if ($Data3.Count -gt 0 -and $DataNames3.Count -gt 0) {
                            Chart -Title 'Member Type Distribution' -TitleAlignment center -Gradient -SubTitle "Across All Groups" -SubTitleColor Blue -SubTitleFontSize 14 {
                                ChartBarOptions -Type bar -DataLabelsOffsetX 15
                                ChartLegend -Name 'Count'
                                for ($i = 0; $i -lt $Data3.Count; $i++) {
                                    if ($i -lt $DataNames3.Count -and $DataNames3[$i]) {
                                        ChartBar -Name $DataNames3[$i] -Value $Data3[$i]
                                    }
                                }
                            }
                        }
                    }
                }
                
                if ($GroupsByAge -and $GroupsByAge.Count -gt 0) {
                    Panel {
                        $Data4 = @($GroupsByAge | ForEach-Object { $_.Count } | Where-Object { $_ -ne $null })
                        $DataNames4 = @($GroupsByAge | ForEach-Object { $_.'Age Range' } | Where-Object { $_ -ne $null -and $_ -ne "" })
                        if ($Data4.Count -gt 0 -and $DataNames4.Count -gt 0) {
                            Chart -Title 'Groups by Age (Creation Date)' -TitleAlignment center -Gradient -SubTitle "Distribution by Creation Date" -SubTitleColor Blue -SubTitleFontSize 14 {
                                ChartBarOptions -Type bar -DataLabelsOffsetX 15
                                ChartLegend -Name 'Count'
                                for ($i = 0; $i -lt $Data4.Count; $i++) {
                                    if ($i -lt $DataNames4.Count -and $DataNames4[$i]) {
                                        ChartBar -Name $DataNames4[$i] -Value $Data4[$i]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            # Top Groups Section
            Section -Name 'Top Groups Analysis' -Collapsable -HeaderBackGroundColor DarkGreen {
                Section -Name 'Top 20 Groups by Member Count' -Collapsable -HeaderBackGroundColor Green {
                    Table -DataTable $TopGroupsByMembers -Filtering -SearchRegularExpression -PagingOptions 10, 20 {}
                }
                
                Section -Name 'Top 20 Groups with Most Nested Groups' -Collapsable -HeaderBackGroundColor Green {
                    Table -DataTable $TopGroupsByNested -Filtering -SearchRegularExpression -PagingOptions 10, 20 {}
                }
            }

            Section -Name 'Top Groups Analysis' -Collapsable -HeaderBackGroundColor DarkGreen {
              
                Section -Name 'Top 10 Groups with Most Computers' -Collapsable -HeaderBackGroundColor Green {
                    Table -DataTable $TopGroupsByComputers -Filtering -SearchRegularExpression -PagingOptions 10 {}
                }
                
                Section -Name 'Top 10 Groups with Most Contacts' -Collapsable -HeaderBackGroundColor Green {
                    Table -DataTable $TopGroupsByContacts -Filtering -SearchRegularExpression -PagingOptions 10 {}
                }
            }
            
            # Age Analysis Section
            Section -Name 'Group Age Analysis' -Collapsable -HeaderBackGroundColor DarkOrange {
                Section -Name 'Top 10 Oldest Groups' -Collapsable -HeaderBackGroundColor Orange {
                    Table -DataTable $TopOldestGroups -Filtering -SearchRegularExpression -PagingOptions 10 {}
                }
                
                if ($GroupsByModificationAge -and $GroupsByModificationAge.Count -gt 0) {
                    Panel {
                        $Data5 = @($GroupsByModificationAge | ForEach-Object { $_.Count } | Where-Object { $_ -ne $null })
                        $DataNames5 = @($GroupsByModificationAge | ForEach-Object { $_.'Modification Range' } | Where-Object { $_ -ne $null -and $_ -ne "" })
                        if ($Data5.Count -gt 0 -and $DataNames5.Count -gt 0) {
                            Chart -Title 'Groups by Last Modification Date' -TitleAlignment center -Gradient -SubTitle "Distribution by Modification Age" -SubTitleColor Blue -SubTitleFontSize 14 {
                                ChartBarOptions -Type bar -DataLabelsOffsetX 15
                                ChartLegend -Name 'Count'
                                for ($i = 0; $i -lt $Data5.Count; $i++) {
                                    if ($i -lt $DataNames5.Count -and $DataNames5[$i]) {
                                        ChartBar -Name $DataNames5[$i] -Value $Data5[$i]
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            # Scope and Category Analysis
            if ($GroupsByScopeCategory -and $GroupsByScopeCategory.Count -gt 0) {
                Section -Name 'Groups by Scope and Category' -Collapsable -HeaderBackGroundColor Indigo {
                    Panel {
                        $Data6 = @($GroupsByScopeCategory | ForEach-Object { $_.Count } | Where-Object { $_ -ne $null })
                        $DataNames6 = @($GroupsByScopeCategory | ForEach-Object { $_.'Scope - Category' } | Where-Object { $_ -ne $null -and $_ -ne "" })
                        if ($Data6.Count -gt 0 -and $DataNames6.Count -gt 0) {
                            Chart -Title 'Groups by Scope-Category Combination' -TitleAlignment center -Gradient -SubTitle "Top 15 Combinations" -SubTitleColor Blue -SubTitleFontSize 14 {
                                ChartBarOptions -Type bar -DataLabelsOffsetX 15
                                ChartLegend -Name 'Count'
                                for ($i = 0; $i -lt $Data6.Count; $i++) {
                                    if ($i -lt $DataNames6.Count -and $DataNames6[$i]) {
                                        ChartBar -Name $DataNames6[$i] -Value $Data6[$i]
                                    }
                                }
                            }
                        }
                    }
                    Section -Name 'Scope-Category Distribution Table' -Collapsable -HeaderBackGroundColor MediumPurple {
                        Table -DataTable $GroupsByScopeCategory -Filtering -SearchRegularExpression -PagingOptions 10, 15 {}
                    }
                }
            }
            
            # OU Distribution Section
            Section -Name 'Organizational Unit Analysis' -Collapsable -HeaderBackGroundColor Purple {
                Section -Name 'Top 30 OUs by Group Count' -Collapsable -HeaderBackGroundColor MediumPurple {
                    Table -DataTable $GroupsByOU -Filtering -SearchRegularExpression -PagingOptions 10, 20, 30 {}
                }
            }
            
            # Members Summary Section
            Section -Name 'Members Summary' -Collapsable -HeaderBackGroundColor Astral {
                foreach ($ouData in $NoMembersByOU) {
                    Section -Name "No Members Groups ($($ouData.OU)) - Count: $($ouData.Count)" -Collapsable -HeaderBackGroundColor Orange {
                        Table -DataTable $ouData.Groups -Filtering -SearchRegularExpression {}
                    }
                }
            }
            
            # Recent Activity Section
            Section -Name 'Recent Activity' -Collapsable -HeaderBackGroundColor DarkCyan {
                Section -Name 'Groups Modified in Last 30 Days' -Collapsable -HeaderBackGroundColor Cyan {
                    Table -DataTable $RecentModified -Filtering -SearchRegularExpression -PagingOptions 10, 20, 30 {}
                }
                
                Section -Name 'Groups Created in Last 90 Days' -Collapsable -HeaderBackGroundColor Cyan {
                    Table -DataTable $RecentCreated -Filtering -SearchRegularExpression -PagingOptions 10, 20, 30 {}
                }
            }
            
            # Governance Section
            Section -Name 'Governance & Compliance' -Collapsable -HeaderBackGroundColor DarkRed {
                Section -Name 'Groups Without Description (Top 50)' -Collapsable -HeaderBackGroundColor Red {
                    Table -DataTable $GroupsNoDescription -Filtering -SearchRegularExpression -PagingOptions 10, 20, 50 {}
                }
                
                Section -Name 'Groups Without Manager (Top 50)' -Collapsable -HeaderBackGroundColor Red {
                    Table -DataTable $GroupsNoManager -Filtering -SearchRegularExpression -PagingOptions 10, 20, 50 {}
                }
                
                Section -Name 'Groups Not Modified in Last Year (Top 30)' -Collapsable -HeaderBackGroundColor Red {
                    Table -DataTable $GroupsNotModifiedYear -Filtering -SearchRegularExpression -PagingOptions 10, 20, 30 {}
                }
            }
        }
        
        Tab -Name 'AD Groups List' {
            New-HTMLSection -HeaderTextSize 12 -HeaderText "Data collected $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -HeaderTextAlignment left -BackgroundColor White -HeaderTextColor Black -HeaderBackGroundColor White {}
            Table -DataTable $ResultOut -PagingOptions 5, 15, 25, 50, 100 -Filtering -SearchRegularExpression
        }
    }
    
    Write-Host "HTML dashboard generated: $outputfileHTML" -ForegroundColor Green
}
catch {
    Write-Error "Failed to generate HTML dashboard: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Copy to Web Path
if ($WebCopyPath) {
    try {
        if (-not (Test-Path (Split-Path $WebCopyPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $WebCopyPath -Parent) -Force | Out-Null
        }
        Copy-Item $outputfileHTML $WebCopyPath -Force
        Write-Host "Dashboard copied to web path: $WebCopyPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to copy to web path: $($_.Exception.Message)"
    }
}
#endregion

#region Completion Summary
$EndMain = Get-Date
$MainElapsedTime = $EndMain - $startMain
$MainElapsedTimeOut = [Math]::Round($MainElapsedTime.TotalMinutes, 3)

Write-Host "`n" -NoNewline
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Script Execution Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Groups Processed: " -NoNewline -ForegroundColor Yellow
Write-Host "$($ResultOut.Count)" -ForegroundColor White
Write-Host "Errors Encountered: " -NoNewline -ForegroundColor Yellow
Write-Host "$errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
Write-Host "Total Elapsed Time: " -NoNewline -ForegroundColor Yellow
Write-Host "$MainElapsedTimeOut Minutes" -ForegroundColor White
Write-Host "CSV Output: " -NoNewline -ForegroundColor Yellow
Write-Host "$output" -ForegroundColor White
Write-Host "HTML Dashboard: " -NoNewline -ForegroundColor Yellow
Write-Host "$outputfileHTML" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
#endregion

#@================Code END===================
