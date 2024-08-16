# SQL Server CPU Information Retrieval

This PowerShell script retrieves follwing information for SQL Server instances listed in a CSV file.
- Get SQL Instance 
- Get SQL Server Edition 
- Get SQL Database counts
- Get SQL CPU Cores 
- Get SQL Model

## Usage

1. Ensure PowerShell execution policy allows running scripts.
2. Prepare a CSV file named `SQLserverlist.csv` with columns `ServerName` and `Environment`.
3. Execute the script.

## Script Overview

1. Reads server names and environment values from `SQLserverlist.csv`.
2. Defines a function `Get-CPUInfo` to retrieve CPU information for a given server.
3. Loops through each server to collect CPU information.
4. Outputs the collected data to CSV and HTML files.

## Functions

### Get-CPUInfo

- **Parameters:**
  - `$ServerName`: Name of the server to retrieve CPU information.
  - `$Environment`: Environment type of the server.
- **Returns:**
  - Object containing server CPU details including server name, instance name, edition, database count, CPU count, total cores, etc.

## Output

- **CSV:** `output.csv` containing CPU information for each SQL Server instance.
- **HTML:** `SQLserverlist_<date>.html` providing an interactive view of CPU details.

## Requirements

- PowerShell environment.
- Access to SQL Server instances for querying CPU information.

## Example CSV Input (SQLserverlist.csv)

```csv
ServerName,Environment
SQLServer1,Production
SQLServer2,Development
...
