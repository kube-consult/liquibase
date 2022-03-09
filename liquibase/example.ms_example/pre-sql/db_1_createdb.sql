-- create database and database owner login and user
-- run as master credentials
-- parameters required: database, password

IF EXISTS 
    (
    SELECT name FROM master.dbo.sysdatabases 
    WHERE name = '$(database)'
    )
BEGIN
    SELECT 'Database already Exist' AS Message
END
ELSE
BEGIN
    CREATE DATABASE [$(database)]
    SELECT 'New Database is Created'
END
GO

IF  EXISTS (SELECT loginname from master.dbo.syslogins 
    WHERE name = '$(database)_dbo' and dbname = '$(database)')
  BEGIN
	  SELECT 'login already Exist' AS Message;
  END
ELSE
  BEGIN
    CREATE LOGIN [$(database)_dbo] with password = "$(password)",
	  DEFAULT_DATABASE= [$(database)]
    SELECT 'New login is Created'
  END
GO

USE [$(database)]
GO

If  EXISTS ( SELECT *   FROM sys.database_principals
  WHERE name = '$(database)_dbo')
  BEGIN
    SELECT 'user already Exist' AS Message
  END
ELSE
  BEGIN
    CREATE USER [$(database)_dbo] FOR LOGIN [$(database)_dbo] 
	WITH DEFAULT_SCHEMA = [dbo]
	SELECT 'New user is Created'
  END
GO

EXEC sp_addrolemember 'db_owner', '$(database)_dbo'
GO
