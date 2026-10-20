/*
    05-covering-index-and-key-lookup.sql

    Run sql/03-create-customer-index.sql first.

    Part A uses only IX_Orders_CustomerId.
    - Selecting OrderId and CustomerId can be satisfied from that index.
      OrderId is stored there as the clustered-key row locator.
    - Selecting OrderDate, Status, and TotalAmount as well may add a
      Key Lookup per qualifying row. The optional index hint below forces
      that index so the Key Lookup operator is visible. A hint is a teaching
      tool here, not a tuning recommendation.
    - The unconstrained full-column queries are the ones to compare. The
      optimizer may seek, seek plus lookup, or scan.

    Part B creates IX_Orders_CustomerId_Covering on CustomerId and includes
    OrderDate, Status, and TotalAmount. OrderId is present automatically as
    the row locator. A query that needs only those columns can be satisfied
    without a Key Lookup.

    The covering index duplicates the key of IX_Orders_CustomerId and stores
    more columns, so it takes more pages and more write maintenance. This
    project keeps both indexes so the plans can be compared. After the
    comparison, the optional DROP at the bottom can remove the narrower index
    when you no longer need that side-by-side example.

    Rerun behavior: if IX_Orders_CustomerId_Covering already exists, the
    script drops that index, runs Part A, then creates it again. It does not
    drop IX_Orders_CustomerId, dbo.Orders, or any other database.

    Measured statements use OPTION (RECOMPILE) so each literal is optimized
    from its histogram step rather than from a reused parameterized plan.
    Press Ctrl+M in SSMS before executing.
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
    PRINT N'Dropping IX_Orders_CustomerId_Covering so Part A can show the narrow index first. It is created again in Part B.';
    DROP INDEX IX_Orders_CustomerId_Covering ON dbo.Orders;
END;
GO

USE IndexSeekScanDemo;
GO

PRINT N'=== Part A. Columns stored in IX_Orders_CustomerId, execution 1 of 2 ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId
FROM dbo.Orders
WHERE CustomerId = 42
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Part A. Columns stored in IX_Orders_CustomerId, execution 2 of 2 ===';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId
FROM dbo.Orders
WHERE CustomerId = 42
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Part A. Full-column CustomerId = 42, unconstrained, execution 1 of 2 ===';
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

PRINT N'=== Part A. Full-column CustomerId = 42, unconstrained, execution 2 of 2 ===';
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

PRINT N'=== Part A. Teaching hint only. Forces IX_Orders_CustomerId for the full-column lookup. ===';
PRINT N'This hint is not a recommendation. Use it to inspect a Key Lookup when you want that operator on screen.';
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT OrderId, CustomerId, OrderDate, Status, TotalAmount
FROM dbo.Orders WITH (INDEX (IX_Orders_CustomerId))
WHERE CustomerId = 42
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'=== Part B. Creating the covering index. ===';
GO

CREATE NONCLUSTERED INDEX IX_Orders_CustomerId_Covering
ON dbo.Orders (CustomerId)
INCLUDE (OrderDate, Status, TotalAmount);
GO

PRINT N'Created IX_Orders_CustomerId_Covering.';
GO

PRINT N'=== Part B. Full-column CustomerId = 42 after the covering index, execution 1 of 2 ===';
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

PRINT N'=== Part B. Full-column CustomerId = 42 after the covering index, execution 2 of 2 ===';
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

PRINT N'=== Part B. Full-column CustomerId = 7 after the covering index, execution 1 of 2 ===';
PRINT N'A covering index removes the lookup. These 19,900 keys are adjacent in the covering index, so compare this logical-read count with the clustered scan from script 04. A different distribution can still favor a scan.';
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

PRINT N'=== Part B. Full-column CustomerId = 7 after the covering index, execution 2 of 2 ===';
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

SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType,
    c.name AS ColumnName,
    ic.key_ordinal,
    ic.is_included_column,
    ps.row_count,
    ps.used_page_count
FROM sys.indexes AS i
JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
JOIN sys.dm_db_partition_stats AS ps
    ON ps.object_id = i.object_id
   AND ps.index_id = i.index_id
WHERE i.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY i.index_id, ic.is_included_column, ic.key_ordinal;

/*
    Optional, after you have finished the comparison.
    IX_Orders_CustomerId_Covering can serve the same CustomerId seeks as
    IX_Orders_CustomerId, plus the included columns. Drop the narrower index
    only when you no longer want the side-by-side example.

    DROP INDEX IX_Orders_CustomerId ON dbo.Orders;
*/
GO
