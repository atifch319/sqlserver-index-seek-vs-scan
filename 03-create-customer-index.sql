/*
    03-create-customer-index.sql

    Run sql/01-create-database-and-data.sql first.
    Run sql/02-baseline-queries.sql before this script when you want a
    before-and-after comparison.

    Creates one nonclustered index on dbo.Orders (CustomerId).
    The leaf level also stores OrderId, because OrderId is the clustered
    key and therefore the row locator. OrderDate, Status, and TotalAmount
    are not stored in this index.

    Safe to rerun: when IX_Orders_CustomerId already exists, the script
    leaves it in place and does not drop it. To rebuild the whole example,
    rerun script 01, which drops dbo.Orders.

    Permission: ALTER on dbo.Orders, or db_owner in IndexSeekScanDemo.
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
    CREATE NONCLUSTERED INDEX IX_Orders_CustomerId
    ON dbo.Orders (CustomerId);

    PRINT N'Created nonclustered index IX_Orders_CustomerId on dbo.Orders (CustomerId).';
END
ELSE
BEGIN
    PRINT N'IX_Orders_CustomerId already exists. This script did not drop or recreate it.';
END;
GO

USE IndexSeekScanDemo;
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

PRINT N'Index statistics for IX_Orders_CustomerId.';
DBCC SHOW_STATISTICS (N'dbo.Orders', N'IX_Orders_CustomerId') WITH STAT_HEADER;
GO
