/* 
Amol Patil
DATE - 05/17/2024
*/

-- Create a temporary table to hold the report for all databases in the server
CREATE TABLE #DbBkpGrowth (
    DBName sysname,
    Year int,
    Month int,
    BkpSizeGB decimal(10, 2),
    DeltaNormal decimal(10, 2),
    CmpBkpSizeGB decimal(10, 2),
    DeltaCmp decimal(10, 2),
    GrowthFromPreviousMonthGB decimal(10, 2) -- Additional column for growth from previous month
);

DECLARE @DBName sysname;
DECLARE @sql NVARCHAR(MAX);

-- Cursor to iterate over user databases
DECLARE db_cursor CURSOR FOR
SELECT name 
FROM sys.databases
WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
AND state_desc = 'ONLINE'; -- Include only online databases

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @sql = N'
        USE [' + @DBName + '];
        WITH BackupsSize AS (
            SELECT 
                bs.[database_name],
                ROW_NUMBER() OVER (PARTITION BY bs.[database_name] ORDER BY DATEPART(year, bs.[backup_start_date]) ASC, DATEPART(month, bs.[backup_start_date]) ASC) AS rn,
                DATEPART(year, bs.[backup_start_date]) AS [Year],
                DATEPART(month, bs.[backup_start_date]) AS [Month],
                CONVERT(decimal(10, 2), ROUND(AVG(bs.[backup_size] / 1024.0 / 1024.0 / 1024.0), 4)) AS [Backup Size GB],
                CONVERT(decimal(10, 2), ROUND(AVG(bs.[compressed_backup_size] / 1024.0 / 1024.0 / 1024.0), 4)) AS [Compressed Backup Size GB]
            FROM msdb.dbo.backupset bs
            WHERE 
                bs.[database_name] = N''' + @DBName + '''
                AND bs.[type] = ''D''
                AND bs.[backup_start_date] BETWEEN DATEADD(mm, -3, GETDATE()) AND GETDATE()
            GROUP BY 
                bs.[database_name], 
                DATEPART(year, bs.[backup_start_date]), 
                DATEPART(month, bs.[backup_start_date])
        )
        
        INSERT INTO #DbBkpGrowth
        SELECT 
            b.[database_name],
            b.[Year],
            b.[Month],
            b.[Backup Size GB],
            COALESCE(b.[Backup Size GB] - d.[Backup Size GB], 0) AS DeltaNormal,
            b.[Compressed Backup Size GB],
            COALESCE(b.[Compressed Backup Size GB] - d.[Compressed Backup Size GB], 0) AS DeltaCmp,
            COALESCE(b.[Backup Size GB] - LAG(b.[Backup Size GB]) OVER (ORDER BY b.[Year], b.[Month]), 0) AS GrowthFromPreviousMonthGB
        FROM BackupsSize b
        LEFT JOIN BackupsSize d ON b.[database_name] = d.[database_name] AND b.rn = d.rn + 1
        WHERE b.rn = 1 OR d.rn IS NOT NULL;
        ';

        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT 'Skipping database ' + @DBName + ' due to access issues: ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM db_cursor INTO @DBName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Select the results from the temporary table and order them
SELECT *
FROM #DbBkpGrowth
ORDER BY DBName, Year, Month, DeltaNormal DESC;

-- Drop the temporary table
DROP TABLE #DbBkpGrowth;
