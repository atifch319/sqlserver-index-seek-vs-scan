/*
    06-cleanup.sql

    DESTRUCTIVE. Run this only when you are finished.

    Drops the database IndexSeekScanDemo and every object inside it.
    The database name is fixed. This script does not drop any other database.

    Connect to the instance you intend to change before executing.
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE ends other sessions in
    IndexSeekScanDemo, then DROP DATABASE removes it.

    Permission: the database owner, or sysadmin. CREATE DATABASE permission
    alone is not always sufficient to drop a database you do not own.

    Safe to rerun when the database is already absent: the script prints a
    message and drops nothing.
*/

USE master;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF DB_ID(N'IndexSeekScanDemo') IS NULL
BEGIN
    PRINT N'IndexSeekScanDemo does not exist. Nothing was dropped.';
END
ELSE
BEGIN
    PRINT N'Dropping database IndexSeekScanDemo. This cannot be undone.';
    ALTER DATABASE IndexSeekScanDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE IndexSeekScanDemo;
    PRINT N'Dropped database IndexSeekScanDemo.';
END;
GO
