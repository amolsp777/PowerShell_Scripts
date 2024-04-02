<#	
	.NOTES
	===========================================================================
     Created on:   	4/2/2024 12:04 PM
	 Created by:   	Amol Patil
	 Organization: 	
	 Filename:     	Get-ADObjectCounts.ps1
	===========================================================================
	.DESCRIPTION
		This script is a PowerShell function that retrieves various counts of Active Directory objects such as users, computers, and groups from a specified domain controller. 
        It utilizes Active Directory cmdlets to gather the required information.
#>

function Get-ADObjectCounts {
    param (
        [string]$domainController = $env:USERDOMAIN
    )

    $results = @{}

    # Get Active and Disabled User Counts
    $results["ActiveUsers"] = (Get-ADUser -Filter {Enabled -eq $true} -Server $domainController | Measure-Object).Count
    $results["DisabledUsers"] = (Get-ADUser -Filter {Enabled -eq $false} -Server $domainController | Measure-Object).Count

    # Get Computer Object Counts
    $results["TotalComputers"] = (Get-ADComputer -Filter * -Server $domainController | Measure-Object).Count
    $results["ActiveComputers"] = (Get-ADComputer -Filter {Enabled -eq $true} -Server $domainController | Measure-Object).Count
    $results["DisabledComputers"] = (Get-ADComputer -Filter {Enabled -eq $false} -Server $domainController | Measure-Object).Count

    # Get Group Counts
    $getGroups = (Get-ADGroup -filter * -Server $domainController  -Properties Members)

    $results["TotalGroups"] = ($getGroups).Count

    # Get Empty Group Counts
    $results["EmptyGroups"] = ($getGroups | Where-Object { ($_.Members).Count -le 0 } | Measure-Object).Count

    # Get Security Group and Distribution Group Counts
    $results["SecurityGroups"] = (Get-ADGroup -Filter {GroupCategory -eq "Security"} -Server $domainController | Measure-Object).Count
    $results["DistributionGroups"] = (Get-ADGroup -Filter {GroupCategory -eq "Distribution"} -Server $domainController | Measure-Object).Count

    return $results
}

# Usage:
$result = Get-ADObjectCounts
$result | Format-Table -AutoSize
