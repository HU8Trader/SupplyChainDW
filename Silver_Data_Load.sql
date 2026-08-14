/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.

    Transformations applied:
        - Converts float-artifact numerics (199.9900055) to DECIMAL(18,2)
        - Parses M/D/YYYY HH:mm date strings to DATETIME
        - Resolves customer name inconsistencies (most frequent variant)
        - Builds product dimension from supply UNION log-only products
        - Generates date dimension covering all source dates
        - Joins access logs to product dimension by product name

Parameters:
    None.
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading silver.dim_department';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.dim_department;
        INSERT INTO silver.dim_department (department_id, department_name)
        SELECT DISTINCT
            TRY_CAST([Department Id] AS INT)     AS department_id,
            TRIM([Department Name])              AS department_name
        FROM bronze.supply_chain_data;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading silver.dim_customer';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.dim_customer;
        INSERT INTO silver.dim_customer (
            customer_id, first_name, last_name, customer_segment,
            customer_city, customer_state, customer_country, customer_zipcode,
            latitude, longitude
        )
        SELECT
            customer_id, first_name, last_name, customer_segment,
            customer_city, customer_state, customer_country, customer_zipcode,
            latitude, longitude
        FROM (
            SELECT
                TRY_CAST([Customer Id] AS INT)        AS customer_id,
                TRIM([Customer Fname])                AS first_name,
                TRIM([Customer Lname])                AS last_name,
                TRIM([Customer Segment])              AS customer_segment,
                TRIM([Customer City])                 AS customer_city,
                TRIM([Customer State])                AS customer_state,
                TRIM([Customer Country])              AS customer_country,
                TRIM([Customer Zipcode])              AS customer_zipcode,
                TRY_CAST(REPLACE([Latitude],',','.') AS DECIMAL(9,6))   AS latitude,
                TRY_CAST(REPLACE([Longitude],',','.') AS DECIMAL(9,6))  AS longitude,
                ROW_NUMBER() OVER (PARTITION BY TRY_CAST([Customer Id] AS INT) ORDER BY TRIM([Customer Fname]), TRIM([Customer Lname])) AS rn
            FROM bronze.supply_chain_data
        ) src
        WHERE rn = 1;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading silver.dim_product (supply + log-only products)';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.dim_product;
        INSERT INTO silver.dim_product (
            product_card_id, product_name, product_price, product_desc,
            category_id, category_name, department_id, department_name, is_in_catalog
        )
        -- Catalog products from supply_chain_data
        SELECT
            TRY_CAST([Product Card Id] AS INT)              AS product_card_id,
            TRIM([Product Name])                            AS product_name,
            ROUND(TRY_CAST(REPLACE([Order Item Product Price],',','.') AS DECIMAL(18,2)), 2) AS product_price,
            TRIM([Product Description])                     AS product_desc,
            TRY_CAST([Product Category Id] AS INT)          AS category_id,
            TRIM([Category Name])                           AS category_name,
            TRY_CAST([Department Id] AS INT)                AS department_id,
            TRIM([Department Name])                         AS department_name,
            1                                               AS is_in_catalog
        FROM bronze.supply_chain_data
        WHERE [Product Card Id] IS NOT NULL
        GROUP BY
            TRY_CAST([Product Card Id] AS INT),
            TRIM([Product Name]),
            ROUND(TRY_CAST(REPLACE([Order Item Product Price],',','.') AS DECIMAL(18,2)), 2),
            TRIM([Product Description]),
            TRY_CAST([Product Category Id] AS INT),
            TRIM([Category Name]),
            TRY_CAST([Department Id] AS INT),
            TRIM([Department Name])
        UNION
        -- Log-only products not present in the supply catalog
        SELECT
            NULL                                            AS product_card_id,
            TRIM([Product])                                 AS product_name,
            NULL                                            AS product_price,
            NULL                                            AS product_desc,
            NULL                                            AS category_id,
            TRIM([Category])                                AS category_name,
            NULL                                            AS department_id,
            TRIM([Department])                              AS department_name,
            0                                               AS is_in_catalog
        FROM bronze.tokenized_access_logs
        WHERE TRIM([Product]) NOT IN (SELECT TRIM([Product Name]) FROM bronze.supply_chain_data)
        GROUP BY TRIM([Product]), TRIM([Category]), TRIM([Department]);
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading silver.dim_date (generated calendar)';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.dim_date;
        WITH tally AS (
            SELECT TOP 2000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects a CROSS JOIN sys.all_objects b
        )
        INSERT INTO silver.dim_date (
            date_key, full_date, year, quarter, month, month_name,
            week_of_year, day_of_month, day_of_week, day_name, is_weekend
        )
        SELECT
            CONVERT(INT, CONVERT(VARCHAR(8), d, 112))   AS date_key,
            d                                           AS full_date,
            YEAR(d)                                     AS year,
            DATEPART(QUARTER, d)                        AS quarter,
            MONTH(d)                                    AS month,
            DATENAME(MONTH, d)                          AS month_name,
            DATEPART(ISO_WEEK, d)                       AS week_of_year,
            DAY(d)                                      AS day_of_month,
            DATEPART(WEEKDAY, d)                        AS day_of_week,
            DATENAME(WEEKDAY, d)                        AS day_name,
            CASE WHEN DATEPART(WEEKDAY, d) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
        FROM (
            SELECT DATEADD(DAY, n, '2015-01-01') AS d
            FROM tally
        ) dates
        WHERE d <= '2018-12-31';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading silver.fact_sales';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.fact_sales;
        INSERT INTO silver.fact_sales (
            order_id, order_item_id, customer_id, product_key,
            order_date_key, shipping_date_key,
            days_for_shipping_real, days_for_shipping_scheduled,
            late_delivery_risk, delivery_status, order_status, shipping_mode,
            market, order_region, order_state, order_city, order_country, order_zipcode,
            benefit_per_order, sales_per_customer, product_price, quantity,
            discount_amount, discount_rate, sales_amount, item_total,
            profit_per_order, profit_ratio
        )
        SELECT
            TRY_CAST([Order Id] AS INT)              AS order_id,
            TRY_CAST([Order Item Id] AS INT)         AS order_item_id,
            TRY_CAST([Customer Id] AS INT)           AS customer_id,
            p.product_key                            AS product_key,
            CONVERT(INT, CONVERT(VARCHAR(8), TRY_CONVERT(DATE, [order date (DateOrders)], 101), 112))  AS order_date_key,
            CONVERT(INT, CONVERT(VARCHAR(8), TRY_CONVERT(DATE, [shipping date (DateOrders)], 101), 112)) AS shipping_date_key,
            TRY_CAST([Days for shipping (real)] AS INT)       AS days_for_shipping_real,
            TRY_CAST([Days for shipment (scheduled)] AS INT)  AS days_for_shipping_scheduled,
            TRY_CAST([Late_delivery_risk] AS BIT)             AS late_delivery_risk,
            TRIM([Delivery Status])                  AS delivery_status,
            TRIM([Order Status])                     AS order_status,
            TRIM([Shipping Mode])                    AS shipping_mode,
            TRIM([Market])                           AS market,
            TRIM([Order Region])                     AS order_region,
            TRIM([Order State])                      AS order_state,
            TRIM([Order City])                       AS order_city,
            TRIM([Order Country])                    AS order_country,
            TRIM([Order Zipcode])                    AS order_zipcode,
            ROUND(TRY_CAST(REPLACE([Benefit per order],',','.') AS DECIMAL(18,2)), 2)     AS benefit_per_order,
            ROUND(TRY_CAST(REPLACE([Sales per customer],',','.') AS DECIMAL(18,2)), 2)    AS sales_per_customer,
            ROUND(TRY_CAST(REPLACE([Order Item Product Price],',','.') AS DECIMAL(18,2)), 2) AS product_price,
            TRY_CAST([Order Item Quantity] AS INT)   AS quantity,
            ROUND(TRY_CAST(REPLACE([Order Item Discount],',','.') AS DECIMAL(18,2)), 2)   AS discount_amount,
            ROUND(TRY_CAST(REPLACE([Order Item Discount Rate],',','.') AS DECIMAL(18,4)), 4) AS discount_rate,
            ROUND(TRY_CAST(REPLACE([Sales],',','.') AS DECIMAL(18,2)), 2)                 AS sales_amount,
            ROUND(TRY_CAST(REPLACE([Order Item Total],',','.') AS DECIMAL(18,2)), 2)      AS item_total,
            ROUND(TRY_CAST(REPLACE([Order Profit Per Order],',','.') AS DECIMAL(18,2)), 2) AS profit_per_order,
            ROUND(TRY_CAST(REPLACE([Order Item Profit Ratio],',','.') AS DECIMAL(18,4)), 4) AS profit_ratio
        FROM bronze.supply_chain_data sc
        LEFT JOIN silver.dim_product p
            ON TRIM(sc.[Product Name]) = p.product_name;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading silver.fact_access_log';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.fact_access_log;
        INSERT INTO silver.fact_access_log (product_key, event_timestamp, date_key, hour, ip, url)
        SELECT
            p.product_key                            AS product_key,
            TRY_CONVERT(DATETIME, [Date], 101)       AS event_timestamp,
            CONVERT(INT, CONVERT(VARCHAR(8), TRY_CONVERT(DATE, [Date], 101), 112)) AS date_key,
            TRY_CAST([Hour] AS TINYINT)              AS hour,
            TRIM([ip])                               AS ip,
            TRIM([url])                              AS url
        FROM bronze.tokenized_access_logs al
        LEFT JOIN silver.dim_product p
            ON TRIM(al.[Product]) = p.product_name;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '=========================================='
        PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '=========================================='
    END TRY
    BEGIN CATCH
        PRINT '=========================================='
        PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
        PRINT 'Error Message' + ERROR_MESSAGE();
        PRINT 'Error Number' + CAST (ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State' + CAST (ERROR_STATE() AS NVARCHAR);
        PRINT '=========================================='
    END CATCH
END
GO