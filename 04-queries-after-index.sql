/*
    04-queries-after-index.sql

    Run sql/03-create-customer-index.sql first.
    The measured statements match sql/02-baseline-queries.sql.

    IX_Orders_CustomerId can locate rows by CustomerId. The leaf of that
    index contains CustomerId and the clustered key OrderId. It does not
    contain OrderDate, Status, or TotalAmount. When the optimizer uses this
    index for the full-column SELECT, the plan also needs a Key Lookup into
    PK_Orders for those columns.

    A Key Lookup repeated for many rows can cost more than a Clustered Index
    Scan. The optimizer compares estimated costs. It can choose a scan for
    CustomerId = 7 even though IX_Orders_CustomerId exists. Do not treat one
    plan shape as guaranteed on every SQL Server version or data distribution.

    Compare execution 2 of each statement with execution 2 from script 02.
    OPTION (RECOMPILE) is repeated here so each CustomerId is estimated from
    its own histogram step. Press Ctrl+M in SSMS before executing, then use
    the Messages tab and the Execution plan tab.
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

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes AS existing_index
    WHERE existing_index.object_id = OBJECT_ID(N'dbo.Orders')
      AND existing_index.name = N'IX_Orders_CustomerId'
)
BEGIN
    THROW 50004, 'IX_Orders_CustomerId does not exist. Run sql/03-create-customer-index.sql first.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM sys.indexes AS existing_index
    WHERE existing_index.object_id = OBJECT_ID(N'dbo.Orders')
      AND existing_index.name = N'IX_Orders_CustomerId_Covering'
)
BEGIN
    PRINT N'WARNING: IX_Orders_CustomerId_Covering already exists. The optimizer may use it. For a comparison against only IX_Orders_CustomerId, rerun script 01 and then scripts 03 and 04.';
END;
GO

USE IndexSeekScanDemo;
GO

PRINT N'=== After IX_Orders_CustomerId, CustomerId = 42 (100 rows), execution 1 of 2 ===';
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

PRINT N'=== After IX_Orders_CustomerId, CustomerId = 42 (100 rows), execution 2 of 2 ===';
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

PRINT N'=== After IX_Orders_CustomerId, CustomerId = 7 (19900 rows), execution 1 of 2 ===';
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

PRINT N'=== After IX_Orders_CustomerId, CustomerId = 7 (19900 rows), execution 2 of 2 ===';
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

PRINT N'=== After IX_Orders_CustomerId, OrderDate range, execution 1 of 2 ===';
PRINT N'The CustomerId index does not order OrderDate. Expect this predicate to keep using the clustered index unless a different useful index exists.';
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

PRINT N'=== After IX_Orders_CustomerId, OrderDate range, execution 2 of 2 ===';
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

/*
    The following statement is not part of the before-and-after pair.
    The unconstrained CustomerId = 7 query above is free to scan.
    This hint forces IX_Orders_CustomerId so you can see the Key Lookup
    alternative and its logical reads. Do not treat the hint as guidance
    for production queries.
*/
PRINT N'=== Extra: forced IX_Orders_CustomerId for CustomerId = 7. The optimizer is not choosing this plan. ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.Orders WITH (INDEX (IX_Orders_CustomerId))
WHERE CustomerId = 7
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
