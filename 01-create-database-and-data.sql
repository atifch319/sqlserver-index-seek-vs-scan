/*
    01-create-database-and-data.sql

    Project: SQL Server Index Seek vs. Index Scan
    Run this script first.

    Creates the database IndexSeekScanDemo when it does not exist, then
    recreates dbo.Orders and loads 100,000 deterministic rows.

    What rerunning does
    - Reuses IndexSeekScanDemo when the database is already present.
    - Refuses to continue when that database contains any user table
      other than dbo.Orders.
    - Drops and recreates only dbo.Orders, including its indexes.
    - Does not drop any other database.

    Recovery model
    - When the database has no user tables yet, the script sets SIMPLE
      recovery so the educational load does not require log backups.
    - On later reruns the recovery model is left as it is.

    Permissions
    - CREATE DATABASE requires sysadmin, or membership in the dbcreator
      server role.
    - The principal that creates the database is its owner and can create
      the table, constraints, and statistics.
    - A later run against an existing database requires ALTER on dbo.Orders
      or db_owner (or equivalent) in IndexSeekScanDemo.

    Design
    - OrderId is an explicit int clustered primary key, not an IDENTITY
      column, so every reload produces the same key values.
    - CustomerId is not a foreign key. This project intentionally has no
      Customers table.
    - OrderDate uses date. Day precision is enough for the predicates below.
    - Status is varchar(12) because the sample values are ASCII, which keeps
      the educational row narrow.
    - TotalAmount is decimal(12, 2), an exact scale, rather than money.
    - The row set is an educational data set. It is not production-representative.

    Distribution, for n = 1 through 100,000
    - CustomerId 42 when n is a multiple of 1000: 100 rows (0.1%).
    - CustomerId 7 when n is a multiple of 5 but not of 1000: 19,900 rows (19.9%).
    - Otherwise CustomerId = 1000 + (n % 5000), which lands in 1000..5999.
    - Status cycles every 20 rows: 5,000 each of Cancelled, Pending,
      Processing, and Shipped, and 80,000 Completed.
    - OrderDate = 1 January 2022 plus (n % 1095) days.
    - TotalAmount = 5.00 + ((n % 25000) * 0.25).
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF DB_ID(N'IndexSeekScanDemo') IS NULL
BEGIN
    PRINT N'Creating database IndexSeekScanDemo.';
    CREATE DATABASE IndexSeekScanDemo;
END
ELSE
BEGIN
    PRINT N'Database IndexSeekScanDemo already exists. It will be reused.';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM IndexSeekScanDemo.sys.tables AS existing_table
    WHERE existing_table.is_ms_shipped = 0
)
BEGIN
    ALTER DATABASE IndexSeekScanDemo SET RECOVERY SIMPLE;
    PRINT N'Set IndexSeekScanDemo to SIMPLE recovery because it has no user tables yet.';
END
ELSE
BEGIN
    PRINT N'IndexSeekScanDemo already has user tables. Recovery model was not changed.';
END;
GO

USE IndexSeekScanDemo;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1
    FROM sys.tables AS existing_table
    WHERE existing_table.is_ms_shipped = 0
      AND NOT (
          existing_table.schema_id = SCHEMA_ID(N'dbo')
          AND existing_table.name = N'Orders'
      )
)
BEGIN
    THROW 50001, 'IndexSeekScanDemo already contains a user table other than dbo.Orders. This script stops rather than changing unrelated tables.', 1;
END;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL
BEGIN
    PRINT N'Dropping dbo.Orders so the educational data set can be recreated.';
    DROP TABLE dbo.Orders;
END;
GO

USE IndexSeekScanDemo;
GO

CREATE TABLE dbo.Orders
(
    OrderId     int            NOT NULL,
    CustomerId  int            NOT NULL,
    OrderDate   date           NOT NULL,
    Status      varchar(12)    NOT NULL,
    TotalAmount decimal(12, 2) NOT NULL,
    CONSTRAINT PK_Orders
        PRIMARY KEY CLUSTERED (OrderId),
    CONSTRAINT CK_Orders_Status
        CHECK (Status IN (N'Pending', N'Processing', N'Shipped', N'Completed', N'Cancelled')),
    CONSTRAINT CK_Orders_TotalAmount
        CHECK (TotalAmount >= 0)
);
GO

USE IndexSeekScanDemo;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

;WITH
    L0 AS (SELECT 1 AS n UNION ALL SELECT 1),
    L1 AS (SELECT 1 AS n FROM L0 AS a CROSS JOIN L0 AS b),
    L2 AS (SELECT 1 AS n FROM L1 AS a CROSS JOIN L1 AS b),
    L3 AS (SELECT 1 AS n FROM L2 AS a CROSS JOIN L2 AS b),
    L4 AS (SELECT 1 AS n FROM L3 AS a CROSS JOIN L3 AS b),
    L5 AS (SELECT 1 AS n FROM L4 AS a CROSS JOIN L0 AS b),
    Nums AS
    (
        SELECT TOP (100000)
               generated.n
        FROM
        (
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM L5
        ) AS generated
        ORDER BY generated.n
    )
INSERT INTO dbo.Orders (OrderId, CustomerId, OrderDate, Status, TotalAmount)
SELECT
    nums.n AS OrderId,
    CASE
        WHEN nums.n % 1000 = 0 THEN 42
        WHEN nums.n % 5 = 0 THEN 7
        ELSE 1000 + (nums.n % 5000)
    END AS CustomerId,
    DATEADD(DAY, nums.n % 1095, CONVERT(date, '20220101')) AS OrderDate,
    CASE nums.n % 20
        WHEN 0 THEN 'Cancelled'
        WHEN 1 THEN 'Pending'
        WHEN 2 THEN 'Processing'
        WHEN 3 THEN 'Shipped'
        ELSE 'Completed'
    END AS Status,
    CONVERT(decimal(12, 2), 5.00 + ((nums.n % 25000) * 0.25)) AS TotalAmount
FROM Nums AS nums
ORDER BY nums.n;

DECLARE @TotalRows int;
DECLARE @Customer42Rows int;
DECLARE @Customer7Rows int;
DECLARE @CompletedRows int;

SELECT @TotalRows = COUNT(*) FROM dbo.Orders;
SELECT @Customer42Rows = COUNT(*) FROM dbo.Orders WHERE CustomerId = 42;
SELECT @Customer7Rows = COUNT(*) FROM dbo.Orders WHERE CustomerId = 7;
SELECT @CompletedRows = COUNT(*) FROM dbo.Orders WHERE Status = N'Completed';

SELECT
    @TotalRows AS TotalRows,
    @Customer42Rows AS Customer42Rows,
    @Customer7Rows AS Customer7Rows,
    @CompletedRows AS CompletedRows;

IF @TotalRows <> 100000
OR @Customer42Rows <> 100
OR @Customer7Rows <> 19900
OR @CompletedRows <> 80000
BEGIN
    THROW 50002, 'Row-count verification failed. Expected 100000 orders, 100 for CustomerId 42, 19900 for CustomerId 7, and 80000 Completed orders.', 1;
END;

CREATE STATISTICS ST_Orders_CustomerId ON dbo.Orders (CustomerId) WITH FULLSCAN;
CREATE STATISTICS ST_Orders_OrderDate ON dbo.Orders (OrderDate) WITH FULLSCAN;
CREATE STATISTICS ST_Orders_Status ON dbo.Orders (Status) WITH FULLSCAN;
UPDATE STATISTICS dbo.Orders PK_Orders WITH FULLSCAN;

SELECT
    N'dbo.Orders' AS TableName,
    MIN(OrderDate) AS MinOrderDate,
    MAX(OrderDate) AS MaxOrderDate,
    MIN(TotalAmount) AS MinTotalAmount,
    MAX(TotalAmount) AS MaxTotalAmount,
    COUNT(DISTINCT CustomerId) AS DistinctCustomers
FROM dbo.Orders;

SELECT
    Status,
    COUNT(*) AS OrderCount
FROM dbo.Orders
GROUP BY Status
ORDER BY Status;

PRINT N'dbo.Orders is ready: 100000 deterministic rows, with statistics updated by a full scan.';
GO
