/* 
===============================================================
Create Database and Schemas
===============================================================
Script Purpose:
	This script creates a new database named 'SupplyChainDW' after checking if it already exists.
	Within the database: 'bronze', 'silver', 'gold', and 'etl' schemas are created.
	WARNING:
		Running this script will drop the entire 'SupplyChainDW' database if it exists.
		All data in the database will be permanently deleted. Proceed with caution
		and ensure you have proper backups before running this script.
		*/
		USE MASTER;
		GO
		---Drop and recreate the 'SupplyChainDW' database
		IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SupplyChainDW')
		BEGIN 
		ALTER DATABASE SupplyChainDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DROP DATABASE SupplyChainDW;
		END;
		GO 
		---Create the 'SupplyChainDW' database
		CREATE DATABASE SupplyChainDW;
		GO
		USE SupplyChainDW;
		--- Create Schemas
		GO
	    CREATE SCHEMA bronze;
		GO 
		CREATE SCHEMA silver;
		GO 
		CREATE SCHEMA gold;
		GO
		CREATE SCHEMA etl;
		GO
