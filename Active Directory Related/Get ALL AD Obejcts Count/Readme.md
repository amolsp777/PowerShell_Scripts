# Get-ADObjectCounts

This script is a PowerShell function that retrieves various counts of Active Directory objects such as users, computers, and groups from a specified domain controller. It utilizes Active Directory cmdlets to gather the required information.

## Parameters

- `domainController`: Specifies the domain controller from which to retrieve the data. Defaults to the current user's domain controller.

## Usage

```powershell
$result = Get-ADObjectCounts
$result | Format-Table -AutoSize
```
## Output
The function returns a hashtable containing counts for different types of Active Directory objects. The output is formatted as a table for easy readability.

- `ActiveUsers` : Count of active users.
- `DisabledUsers` : Count of disabled users.
- `TotalComputers` : Total count of computer objects.
- `ActiveComputers` : Count of active computers.
- `DisabledComputers` : Count of disabled computers.
- `TotalGroups` : Total count of groups.
- `EmptyGroups` : Count of empty groups (groups with no members).
- `SecurityGroups` : Count of security groups.
- `DistributionGroups` : Count of distribution groups.

## Example 

```powershell
$result = Get-ADObjectCounts
$result | Format-Table -AutoSize
```

### Sample Output:
```markdown
ActiveUsers DisabledUsers TotalComputers ActiveComputers DisabledComputers TotalGroups EmptyGroups SecurityGroups DistributionGroups
----------- ------------- --------------- --------------- ---------------- ----------- ----------- --------------- ------------------
       1500            200            1000            950               50          80           5              40                 40
```
Sample Ouptup as List

```markdown
Name               Value
----               -----
DisabledUsers      168
DistributionGroups 100
SecurityGroups     1469
ActiveUsers        932
EmptyGroups        397
ActiveComputers    645
TotalComputers     748
DisabledComputers  103
TotalGroups        1569
```