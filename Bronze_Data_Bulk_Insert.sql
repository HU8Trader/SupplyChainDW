/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from CSV Files to bronze tables.
    - Loads the Description.csv data dictionary into etl.field_dictionary.
    - Registers source metadata in etl.source_metadata.

Parameters:
    None.
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '================================================';
		PRINT 'Loading Bronze Layer';
		PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading bronze.supply_chain_data (SupplyChainData.csv)';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.supply_chain_data';
		TRUNCATE TABLE bronze.supply_chain_data;
		PRINT '>> Inserting Data Into: bronze.supply_chain_data';
		BULK INSERT bronze.supply_chain_data
		FROM 'C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN\SupplyChainData.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '\n',
			CODEPAGE = '1252',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading bronze.tokenized_access_logs (tokenized_access_logs.csv)';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: bronze.tokenized_access_logs';
		TRUNCATE TABLE bronze.tokenized_access_logs;
		PRINT '>> Inserting Data Into: bronze.tokenized_access_logs';
		BULK INSERT bronze.tokenized_access_logs
		FROM 'C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN\tokenized_access_logs.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '\n',
			CODEPAGE = '1252',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading etl.field_dictionary (Description.csv - data dictionary)';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: etl.field_dictionary';
		TRUNCATE TABLE etl.field_dictionary;
		PRINT '>> Inserting Data Into: etl.field_dictionary';
		BULK INSERT etl.field_dictionary
		FROM 'C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN\Description.csv'
		WITH (
			FIRSTROW = 2,
			FORMATFILE = 'C:\Users\pc\Documents\SQL Server Management Studio 22\SupplyChainDW_SQLScripts\description_format.xml'
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Registering Source Metadata (etl.source_metadata)';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		DELETE FROM etl.source_metadata;
		INSERT INTO etl.source_metadata (
			source_name, source_description, source_file_name, source_folder, file_extension,
			destination_schema, destination_table, field_terminator, row_terminator,
			first_row, text_qualifier, file_encoding, load_type, is_header_present
		) VALUES
		('SupplyChain Orders', 'Brazilian e-commerce supply chain order data (53 cols)', 'SupplyChainData.csv',
		 'C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN', '.csv', 'bronze', 'supply_chain_data',
		 ',', '\n', 2, NULL, 'Windows-1252', 'FULL', 1),
		('Access Logs', 'Tokenized product access logs (8 cols)', 'tokenized_access_logs.csv',
		 'C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN', '.csv', 'bronze', 'tokenized_access_logs',
		 ',', '\n', 2, NULL, 'Windows-1252', 'FULL', 1),
		('Field Dictionary', 'Data dictionary describing SupplyChainData columns', 'Description.csv',
		 'C:\Users\pc\documents\HiLyst DataSets\SUPPLYCHAIN', '.csv', 'etl', 'field_dictionary',
		 ',', '\r\n', 2, '"', 'Windows-1252', 'FULL', 1);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Bronze Layer is Completed';
		PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
	END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Number' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END
GO