# Get-ADObjectCounts

The ```Get-ADObjectCounts``` script retrieves various counts related to Active Directory (AD) objects, such as users, computers, and groups. It can be useful for administrators managing AD environments. Let’s break down what this script does:

## Purpose
The purpose of this script is to provide an overview of the following AD object counts:

- Active Users: Number of enabled user accounts.
- Disabled Users: Number of disabled user accounts.
- Total Computers: Total count of computer objects.
- Active Computers: Number of enabled computer accounts.
- Disabled Computers: Number of disabled computer accounts.
- Total Groups: Total count of AD groups.
- Empty Groups: Number of AD groups with no members.
- Security Groups: Number of security groups.
- Distribution Groups: Number of distribution groups.

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
DisabledUsers      200
DistributionGroups 40
SecurityGroups     40
ActiveUsers        1500
EmptyGroups        5
ActiveComputers    950
TotalComputers     1000
DisabledComputers  50
TotalGroups        80
```

## Notes
- Make sure you have appropriate permissions to query AD objects.
- Modify the ```$domainController``` parameter if you want to specify a different domain controller.