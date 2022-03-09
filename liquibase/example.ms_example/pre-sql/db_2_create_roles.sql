
-- create database readonly and application readwrite login and user
-- run as master credentials
-- parameters required: database, password_ro, password_rw

IF  EXISTS (SELECT loginname from master.dbo.syslogins 
    WHERE name = '$(database)_ro' and dbname = '$(database)')
  BEGIN
	  SELECT 'read only login already Exist' AS Message;
  END
ELSE
  BEGIN
    CREATE LOGIN [$(database)_ro] with password = "$(password_ro)",
	  DEFAULT_DATABASE= [$(database)]
    SELECT 'New read only login is Created'
  END
GO

USE [$(database)]
GO

If  EXISTS ( SELECT *   FROM sys.database_principals
  WHERE name = '$(database)_ro')
  BEGIN
    SELECT 'read only user already Exist' AS Message
  END
ELSE
  BEGIN
    CREATE USER [$(database)_ro] FOR LOGIN [$(database)_ro] 
	WITH DEFAULT_SCHEMA = [dbo]
	SELECT 'New read only user is Created'
  END
GO

EXEC sp_addrolemember 'db_datareader', '$(database)_ro'
GO

--read write user

IF  EXISTS (SELECT loginname from master.dbo.syslogins 
    WHERE name = '$(database)_rw' and dbname = '$(database)')
  BEGIN
	  SELECT 'read write login already Exist' AS Message;
  END
ELSE
  BEGIN
    CREATE LOGIN [$(database)_rw] with password = "$(password_rw)",
	  DEFAULT_DATABASE= [$(database)]
    SELECT 'New read write login is Created'
  END
GO

USE [$(database)]
GO

If  EXISTS ( SELECT *   FROM sys.database_principals
  WHERE name = '$(database)_rw')
  BEGIN
    SELECT 'read write user already Exist' AS Message
  END
ELSE
  BEGIN
    CREATE USER [$(database)_rw] FOR LOGIN [$(database)_rw] 
	WITH DEFAULT_SCHEMA = [dbo]
	SELECT 'New read write user is Created'
  END
GO 

EXEC sp_addrolemember 'db_datawriter', '$(database)_rw'
GO