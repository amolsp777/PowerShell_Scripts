#@=============================================
#@ FileName: Generate-SampleDashboard.ps1
#@=============================================
#@ Script Name: Generate-SampleDashboard
#@ Purpose: Generate HTML dashboard with sample/dummy data for demonstration
#@ Requirements: PSWriteHTML Module only (No AD required)
#@ Version: 1.0
#@=============================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = $PSScriptRoot,
    
    [Parameter(Mandatory = $false)]
    [int]$NumberOfGroups = 150
)

#region Module Validation
if (-not (Get-Module -ListAvailable -Name PSWriteHTML)) {
    Write-Error "Required module 'PSWriteHTML' is not installed. Please install it using: Install-Module -Name PSWriteHTML"
    exit 1
}
Import-Module PSWriteHTML -ErrorAction Stop
#endregion

Write-Host "Generating sample data for $NumberOfGroups groups..." -ForegroundColor Cyan

#region Generate Sample Data
$ResultOut = @()
$groupNames = @(
    "Domain Admins", "Domain Users", "Enterprise Admins", "Schema Admins",
    "IT Administrators", "Security Team", "Help Desk", "Developers",
    "Database Admins", "Network Team", "Sales Team", "Marketing",
    "HR Department", "Finance Team", "Executive Team", "Managers",
    "Project Managers", "QA Team", "Operations", "Infrastructure",
    "Application Support", "Service Desk", "Compliance Team", "Audit Team",
    "Backup Operators", "Print Operators", "Server Operators", "Account Operators",
    "Remote Desktop Users", "Power Users", "Guests", "Users",
    "Exchange Administrators", "SQL Server Admins", "SharePoint Admins",
    "File Server Access", "VPN Users", "WiFi Users", "Email Distribution",
    "Security Group Alpha", "Security Group Beta", "Distribution Group 1",
    "Distribution Group 2", "Test Group 1", "Test Group 2", "Archive Group"
)

$scopes = @("DomainLocal", "Global", "Universal")
$categories = @("Security", "Distribution")
$ouPaths = @(
    "OU=Groups,OU=IT,OU=Departments",
    "OU=Security Groups,OU=IT",
    "OU=Distribution Groups,OU=IT",
    "OU=Groups,OU=HR",
    "OU=Groups,OU=Finance",
    "OU=Groups,OU=Sales",
    "OU=Groups,OU=Operations",
    "OU=Groups,OU=Infrastructure",
    "OU=Groups,CN=Users"
)

$descriptions = @(
    "Administrative group for IT operations",
    "Security group for application access",
    "Distribution group for email notifications",
    "Group for department collaboration",
    "Access control group",
    "Resource access group",
    $null, $null, $null  # Some without description
)

$managedBy = @(
    "CN=John Doe,OU=Users,DC=contoso,DC=com",
    "CN=Jane Smith,OU=Users,DC=contoso,DC=com",
    "CN=Admin User,OU=Users,DC=contoso,DC=com",
    $null, $null, $null  # Some without manager
)

$random = New-Object System.Random

for ($i = 0; $i -lt $NumberOfGroups; $i++) {
    $groupName = if ($i -lt $groupNames.Count) { 
        $groupNames[$i] 
    } else { 
        "Group_$($i + 1)" 
    }
    
    # Generate random member counts
    $memCount = $random.Next(0, 500)
    $userCount = [math]::Round($memCount * 0.7)
    $groupCount = $random.Next(0, [math]::Min(20, [math]::Round($memCount * 0.1)))
    $computerCount = $random.Next(0, [math]::Min(50, [math]::Round($memCount * 0.15)))
    $contactCount = $random.Next(0, [math]::Min(10, [math]::Round($memCount * 0.05)))
    $nestedGroupCount = $groupCount
    
    # Adjust total to match
    $memCount = $userCount + $groupCount + $computerCount + $contactCount
    
    # Generate member names
    $memberNames = @()
    if ($userCount -gt 0) {
        for ($j = 1; $j -le [math]::Min($userCount, 10); $j++) {
            $memberNames += "User$j"
        }
        if ($userCount -gt 10) { $memberNames += "... and $($userCount - 10) more users" }
    }
    if ($groupCount -gt 0) {
        for ($j = 1; $j -le [math]::Min($groupCount, 5); $j++) {
            $memberNames += "NestedGroup$j"
        }
        if ($groupCount -gt 5) { $memberNames += "... and $($groupCount - 5) more groups" }
    }
    $MemNames1 = $memberNames -join ",`n"
    
    # Generate dates
    $daysSinceCreated = $random.Next(30, 3650)  # 30 days to 10 years
    $daysSinceModified = $random.Next(0, $daysSinceCreated)
    $whenCreated = (Get-Date).AddDays(-$daysSinceCreated)
    $whenChanged = (Get-Date).AddDays(-$daysSinceModified)
    
    # Generate OU and DN
    $ouPath = $ouPaths[$random.Next(0, $ouPaths.Count)]
    $dn = "CN=$groupName,$ouPath,DC=contoso,DC=com"
    
    # Random properties
    $scope = $scopes[$random.Next(0, $scopes.Count)]
    $category = $categories[$random.Next(0, $categories.Count)]
    $description = $descriptions[$random.Next(0, $descriptions.Count)]
    $manager = $managedBy[$random.Next(0, $managedBy.Count)]
    
    $membersType = @()
    if ($userCount -gt 0) { $membersType += "user" }
    if ($groupCount -gt 0) { $membersType += "group" }
    if ($computerCount -gt 0) { $membersType += "computer" }
    if ($contactCount -gt 0) { $membersType += "contact" }
    $membersTypeStr = $membersType -join ",`n"
    
    $nestedGroupNames = if ($groupCount -gt 0) {
        (1..[math]::Min($groupCount, 5)) | ForEach-Object { "NestedGroup$_" } | ForEach-Object { $_ }
        if ($groupCount -gt 5) { "... and $($groupCount - 5) more" }
    } else { "" }
    $memASGrpName = if ($nestedGroupNames) { ($nestedGroupNames -join ",`n") } else { "" }
    
    $Results = [PSCustomObject]@{
        Group                = $groupName
        MembersCount         = $memCount
        UserCount            = $userCount
        GroupCount           = $groupCount
        ComputerCount        = $computerCount
        ContactCount         = $contactCount
        NestedGroupCount     = $nestedGroupCount
        MembersName          = $MemNames1
        MembersType          = $membersTypeStr
        MembersAsGroup       = $memASGrpName
        Info                 = "Sample data - Group information"
        Description          = $description
        HasDescription       = [bool]$description
        GroupCategory        = $category
        GroupScope           = $scope
        ManagedBy            = $manager
        HasManager           = [bool]$manager
        DistinguishedName    = $dn
        OUPath               = $ouPath
        whenCreated          = $whenCreated
        whenChanged          = $whenChanged
        DaysSinceCreated     = $daysSinceCreated
        DaysSinceModified    = $daysSinceModified
    }
    
    $ResultOut += $Results
}

Write-Host "Sample data generated: $($ResultOut.Count) groups" -ForegroundColor Green
#endregion

#region Generate Statistics (Same as main script)
$importData = $ResultOut
$Date = Get-Date -Format "dd-MM-yyyy"
$outputfileHTML = Join-Path $OutputPath "AD_Groups_List_Sample_$Date.html"

#region Basic Statistics
$totalGroups = $importData.Count
$groupsWithMembers = ($importData | Where-Object { [int]$_.MembersCount -gt 0 }).Count
$groupsWithoutMembers = ($importData | Where-Object { [int]$_.MembersCount -le 0 }).Count
$totalMembers = ($importData | Measure-Object -Property MembersCount -Sum).Sum
$avgMembersPerGroup = if ($groupsWithMembers -gt 0) { [math]::Round($totalMembers / $groupsWithMembers, 2) } else { 0 }
$totalUsers = ($importData | Measure-Object -Property UserCount -Sum).Sum
$totalNestedGroups = ($importData | Measure-Object -Property NestedGroupCount -Sum).Sum
$groupsWithDescription = ($importData | Where-Object { $_.HasDescription -eq $true }).Count
$groupsWithManager = ($importData | Where-Object { $_.HasManager -eq $true }).Count
$totalComputers = ($importData | Measure-Object -Property ComputerCount -Sum).Sum
$totalContacts = ($importData | Measure-Object -Property ContactCount -Sum).Sum
$groupsWithNestedGroups = ($importData | Where-Object { [int]$_.NestedGroupCount -gt 0 }).Count
$groupsWithComputers = ($importData | Where-Object { [int]$_.ComputerCount -gt 0 }).Count
$groupsWithContacts = ($importData | Where-Object { [int]$_.ContactCount -gt 0 }).Count

# Calculate average age
$groupsWithAge = $importData | Where-Object { $_.DaysSinceCreated -ne $null }
$avgGroupAge = if ($groupsWithAge.Count -gt 0) { 
    [math]::Round(($groupsWithAge | Measure-Object -Property DaysSinceCreated -Average).Average, 0) 
} else { 0 }
$avgGroupAgeYears = [math]::Round($avgGroupAge / 365, 1)

$groupsNeverModified = ($importData | Where-Object { 
    $created = $_.DaysSinceCreated
    $modified = $_.DaysSinceModified
    $created -ne $null -and $modified -ne $null -and 
    [int]$created -eq [int]$modified
}).Count

$groupsModifiedAfterCreation = ($importData | Where-Object { 
    $created = $_.DaysSinceCreated
    $modified = $_.DaysSinceModified
    $created -ne $null -and $modified -ne $null -and 
    [int]$modified -lt [int]$created
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
    Where-Object { [int]$_.MembersCount -gt 0 } | 
    Sort-Object { [int]$_.MembersCount } -Descending | 
    Select-Object -First 20 Group, MembersCount, UserCount, GroupCount, ComputerCount, NestedGroupCount, DistinguishedName
#endregion

#region Groups with Most Nested Groups
$TopGroupsByNested = $importData | 
    Where-Object { [int]$_.NestedGroupCount -gt 0 } | 
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
            ($_.Group | Measure-Object -Property MembersCount -Sum).Sum 
        }
    } | 
    Sort-Object 'Group Count' -Descending | 
    Select-Object -First 30
#endregion

#region Member Type Distribution
$MemberTypeStats = @(
    [PSCustomObject]@{ Type = "Users"; Count = $totalUsers }
    [PSCustomObject]@{ Type = "Groups"; Count = $totalNestedGroups }
    [PSCustomObject]@{ Type = "Computers"; Count = $totalComputers }
    [PSCustomObject]@{ Type = "Contacts"; Count = $totalContacts }
)
#endregion

#region Groups Without Members by OU
$NoMembersByOU = @()
$filterOUs = @("OU=Groups,OU=IT", "OU=Security Groups")
foreach ($ouFilter in $filterOUs) {
    $ouGroups = $importData | 
        Where-Object { 
            ([int]$_.MembersCount -le 0) -and 
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

#region Groups Recently Modified
$RecentModified = $importData | 
    Where-Object { 
        $val = $_.DaysSinceModified
        $val -ne $null -and [int]$val -le 30 
    } | 
    Sort-Object { [int]$_.DaysSinceModified } | 
    Select-Object Group, DaysSinceModified, MembersCount, whenChanged, DistinguishedName | 
    Select-Object -First 30
#endregion

#region Groups Recently Created
$RecentCreated = $importData | 
    Where-Object { 
        $val = $_.DaysSinceCreated
        $val -ne $null -and [int]$val -le 90 
    } | 
    Sort-Object { [int]$_.DaysSinceCreated } | 
    Select-Object Group, DaysSinceCreated, MembersCount, whenCreated, DistinguishedName | 
    Select-Object -First 30
#endregion

#region Groups Without Description
$GroupsNoDescription = $importData | 
    Where-Object { $_.HasDescription -ne $true -or -not $_.Description } | 
    Select-Object Group, MembersCount, DistinguishedName | 
    Sort-Object Group | 
    Select-Object -First 50
#endregion

#region Groups Without Manager
$GroupsNoManager = $importData | 
    Where-Object { $_.HasManager -ne $true -or -not $_.ManagedBy } | 
    Select-Object Group, MembersCount, DistinguishedName | 
    Sort-Object Group | 
    Select-Object -First 50
#endregion

#region Groups by Age
$GroupsByAge = $importData | 
    Where-Object { $_.DaysSinceCreated -ne $null } | 
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
#endregion

#region Top 10 Oldest Groups
$TopOldestGroups = $importData | 
    Where-Object { $_.DaysSinceCreated -ne $null } | 
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

#region Groups by Modification Date
$GroupsByModificationAge = $importData | 
    Where-Object { $_.DaysSinceModified -ne $null } | 
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

#region Top Groups by Computers
$TopGroupsByComputers = $importData | 
    Where-Object { [int]$_.ComputerCount -gt 0 } | 
    Sort-Object { [int]$_.ComputerCount } -Descending | 
    Select-Object -First 10 Group, ComputerCount, MembersCount, DistinguishedName
#endregion

#region Top Groups by Contacts
$TopGroupsByContacts = $importData | 
    Where-Object { [int]$_.ContactCount -gt 0 } | 
    Sort-Object { [int]$_.ContactCount } -Descending | 
    Select-Object -First 10 Group, ContactCount, MembersCount, DistinguishedName
#endregion

#region Groups by Scope and Category
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
        $val -ne $null -and [int]$val -gt 365 
    } | 
    Sort-Object { [int]$_.DaysSinceModified } -Descending | 
    Select-Object Group, DaysSinceModified, whenChanged, MembersCount, DistinguishedName | 
    Select-Object -First 30
#endregion
#endregion

#region Generate HTML Dashboard
Write-Host "Generating HTML dashboard with sample data..." -ForegroundColor Cyan
try {
    Dashboard -Name 'Active Directory Groups Report (Sample Data)' -FilePath $outputfileHTML {
        Tab -Name 'Dashboard' {
            New-HTMLSection -HeaderTextSize 12 -HeaderText "Sample Data - Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - This is a demonstration report with dummy data" -HeaderTextAlignment left -BackgroundColor White -HeaderTextColor Black -HeaderBackGroundColor White {}
            
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
            New-HTMLSection -HeaderTextSize 12 -HeaderText "Sample Data - Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - This is a demonstration report with dummy data" -HeaderTextAlignment left -BackgroundColor White -HeaderTextColor Black -HeaderBackGroundColor White {}
            Table -DataTable $ResultOut -PagingOptions 5, 15, 25, 50, 100 -Filtering -SearchRegularExpression
        }
    }
    
    Write-Host "HTML dashboard generated: $outputfileHTML" -ForegroundColor Green
    Write-Host "`nSample dashboard created successfully!" -ForegroundColor Green
    Write-Host "Open the file in a web browser to view the report." -ForegroundColor Yellow
}
catch {
    Write-Error "Failed to generate HTML dashboard: $($_.Exception.Message)"
    exit 1
}
#endregion

