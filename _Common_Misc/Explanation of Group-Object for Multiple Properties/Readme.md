## Explanation of `Group-Object` for Multiple Properties
The `Group-Object` cmdlet in PowerShell groups objects based on the value of specified properties. When you want to group by multiple properties, you can specify them in a comma-separated list. This is useful for organizing data and performing calculations on grouped data.

### Example
Let’s say you have a CSV file with data about employees, including their department and job title. You want to group the data by both department and job title and then calculate the total salary for each group.

#### Sample CSV (`employees.csv`)
```csv
Name,Department,JobTitle,Salary
Alice,HR,Manager,70000
Bob,IT,Developer,80000
Charlie,HR,Assistant,40000
David,IT,Developer,85000
Eve,HR,Manager,75000
```

#### PowerShell Script
```powershell
# Import the CSV file
$employees = Import-Csv -Path "employees.csv"

# Group by Department and JobTitle
$groupedEmployees = $employees | Group-Object -Property Department, JobTitle

# Display the grouped data with total salary for each group
$groupedEmployees | ForEach-Object {
    $groupName = $_.Name -join ", "
    $totalSalary = ($_.Group | Measure-Object -Property Salary -Sum).Sum
    [PSCustomObject]@{
        Group = $groupName
        TotalSalary = $totalSalary
    }
} | Format-Table -AutoSize
```

### Example Output
```powershell
Group             TotalSalary
-----             -----------
HR, Manager       145000
IT, Developer     165000
HR, Assistant     40000

```
This script groups employees by their department and job title and calculates the total salary for each group.

#### Other PowerShell Script example
```powershell
# Group by ZoneName and RecordType, then count the records
$groupedData = $csvData | Group-Object -Property ZoneName, RecordType | Select-Object @{Name="ZoneName";Expression={$_.Group[0].ZoneName}}, @{Name="RecordType";Expression={$_.Group[0].RecordType}}, Count
```
### Example Output

```powershell
ZoneName RecordType Count
-------- ---------- -----
Zone1    A          10
Zone1    CNAME      5
Zone2    A          24

```