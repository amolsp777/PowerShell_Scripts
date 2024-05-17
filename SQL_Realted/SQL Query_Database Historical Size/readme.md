# Database Backup Growth Report

This script generates a report on the backup growth for databases within a SQL Server instance over the last three months.

## Usage

1. Execute the SQL script provided in a SQL Server Management Studio (SSMS) query window.
2. Ensure that the necessary permissions are granted to access the `msdb` database for backup history information.
3. The script will create a temporary table `#DbBkpGrowth` to hold the report data.
4. It iterates over each user database (excluding system databases like `master`, `tempdb`, `model`, and `msdb`).
5. For each database, it calculates the average backup sizes for the last three months and inserts the data into the temporary table.
6. The report includes columns for database name, year, month, backup size in GB, delta normal (growth from the previous month in GB), compressed backup size in GB, delta compressed (growth from the previous month in GB), and growth from the previous month in GB.
7. The final report is sorted by database name, year, month, and delta normal (descending order).
8. The temporary table `#DbBkpGrowth` is dropped after generating the report.

## Requirements

- SQL Server Management Studio (SSMS) or any SQL query execution tool.
- Appropriate permissions to access backup history information in the `msdb` database.

## Important Note

Ensure that you review and test the script in a non-production environment before executing it in a production environment. 

## License

This script is provided under the [MIT License](LICENSE).

