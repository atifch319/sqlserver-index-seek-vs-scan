/*
    02-baseline-queries.sql

    Run sql/01-create-database-and-data.sql first.
    Run this script before sql/03-create-customer-index.sql.

    These queries filter dbo.Orders before a nonclustered index on
    CustomerId exists. The clustered primary key is on OrderId, so a
    CustomerId predicate has no matching index key yet.

    In SSMS, before you execute:
    1. Press Ctrl+M (Include Actual Execution Plan).
    2. Execute this script.
    3. Read logical reads, CPU time, and elapsed time in the Messages tab.
    4. Open the Execution plan tab and select each operator. Press F4 for
       estimated rows, actual rows, and the object name.

    Each measured statement runs twice and uses OPTION (RECOMPILE).
    RECOMPILE makes SQL Server optimize that statement's literal values from
    current statistics instead of reusing a simple-parameterization plan built
    for a different CustomerId. Compile cost is included in CPU time and
    elapsed time. Logical reads are the stable comparison.

    Use execution 2 when you compare this script with
    sql/04-queries-after-index.sql. Cache state, server load, parallelism,
    and the SQL Server version still affect CPU time and elapsed time.

    Optional in SSMS for the 19,900-row result: Query > Query Options >
    Results > Discard results after execution. That reduces client rendering.
    It does not change the logical-read count.

    This script does not promise a particular operator. Capture the actual
    plan on your instance.
*/

USE IndexSeekScanDemo;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
    THROW 50003, 'dbo.Orders does not exist. Run sql/01-create-database-and-data.sql first.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM sys.indexes AS existing_index
    WHERE existing_index.object_id = OBJECT_ID(N'dbo.Orders')
      AND existing_index.index_id > 1
      AND existing_index.is_hypothetical = 0
)
BEGIN
    PRINT N'WARNING: dbo.Orders already has a nonclustered index. These results are not a pre-index baseline. Rerun sql/01-create-database-and-data.sql before comparing them with script 04.';
END;

PRINT N'Cardinality of the predicates used below.';
SELECT CustomerId, COUNT(*) AS OrderCount
FROM dbo.Orders
WHERE CustomerId IN (7, 42)
GROUP BY CustomerId
ORDER BY CustomerId;

SELECT COUNT(*) AS OrdersFrom2022Through2023
FROM dbo.Orders
WHERE OrderDate >= CONVERT(date, '20220101')
  AND OrderDate < CONVERT(date, '20240101');

PRINT N'Statistics header for CustomerId. This is not an access path.';
DBCC SHOW_STATISTICS (N'dbo.Orders', N'ST_Orders_CustomerId') WITH STAT_HEADER;
GO

USE IndexSeekScanDemo;
GO

PRINT N'=== Baseline, CustomerId = 42 (100 rows), execution 1 of 2 ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.Orders
WHERE CustomerId = 42
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Baseline, CustomerId = 42 (100 rows), execution 2 of 2 ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.Orders
WHERE CustomerId = 42
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Baseline, CustomerId = 7 (19900 rows), execution 1 of 2 ===';
PRINT N'Reading about 19.9 percent of the table can make a scan cheaper than many separate lookups once an index exists. Before that index exists, the engine has no CustomerId seek path.';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.Orders
WHERE CustomerId = 7
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Baseline, CustomerId = 7 (19900 rows), execution 2 of 2 ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.Orders
WHERE CustomerId = 7
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Baseline, OrderDate range, execution 1 of 2 ===';
PRINT N'This predicate is not on the clustered key. A later index on CustomerId does not supply an ordered path for OrderDate.';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT
    COUNT(*) AS OrdersInRange,
    SUM(TotalAmount) AS TotalAmountInRange
FROM dbo.Orders
WHERE OrderDate >= CONVERT(date, '20220101')
  AND OrderDate < CONVERT(date, '20240101')
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Baseline, OrderDate range, execution 2 of 2 ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT
    COUNT(*) AS OrdersInRange,
    SUM(TotalAmount) AS TotalAmountInRange
FROM dbo.Orders
WHERE OrderDate >= CONVERT(date, '20220101')
  AND OrderDate < CONVERT(date, '20240101')
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
