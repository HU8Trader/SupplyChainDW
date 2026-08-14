/* 
====================================================================================
Quality Checks
Script Purpose:
	This script performs various quality checks for data consistency, accuracy,
	and standardization across the 'silver' layer. It includes checks for:
	-Null or duplicate primary keys.
	-unwanted spaces in string fields. 
	-Data standardization and consistency.
	-Invalid date ranges and orders.
	-Data consistency between related fields.

Usage Notes:
	-Run these checks after data loading Silver Layer.
	-Investigate and resolve any discrepancies found during the checks.
	==================================================================================
*/

--- ==========================================================================
--- Checking 'silver.dim_customer'
--- ==========================================================================
--- Check for NULLs or Duplicates in Primary Key
--- Expectation: No Results
SELECT 
	customer_id,
	COUNT(*)
FROM silver.dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1 OR customer_id IS NULL;

--- Check for Unwanted Spaces
--- Expectation: No Results
SELECT 
	customer_id
FROM silver.dim_customer
WHERE first_name != TRIM(first_name) OR last_name != TRIM(last_name);

--- Check Data Standardization (country should be 2 values: EE.UU., Puerto Rico)
--- Expectation: Only EE.UU. and Puerto Rico
SELECT DISTINCT
	customer_country
FROM silver.dim_customer;

--- ==========================================================================
--- Checking 'silver.dim_product'
--- ==========================================================================
--- Check for NULLs or Duplicates in Primary Key
--- Expectation: No Results
SELECT 
	product_key,
	COUNT(*)
FROM silver.dim_product
GROUP BY product_key
HAVING COUNT(*) > 1 OR product_key IS NULL;

--- Check that catalog products have a product_card_id
--- Expectation: No Results
SELECT 
	product_key
FROM silver.dim_product
WHERE is_in_catalog = 1 AND product_card_id IS NULL;

--- Expectation: 4 log-only products (is_in_catalog = 0)
SELECT 
	is_in_catalog,
	COUNT(*) AS product_count
FROM silver.dim_product
GROUP BY is_in_catalog;

--- Check for Unwanted Spaces in product names
--- Expectation: No Results
SELECT 
	product_key
FROM silver.dim_product
WHERE product_name != TRIM(product_name);

--- ==========================================================================
--- Checking 'silver.dim_department'
--- ==========================================================================
--- Check for NULLs or Duplicates in Primary Key
--- Expectation: No Results
SELECT 
	department_id,
	COUNT(*)
FROM silver.dim_department
GROUP BY department_id
HAVING COUNT(*) > 1 OR department_id IS NULL;

--- Check for Unwanted Spaces
--- Expectation: No Results
SELECT 
	department_id
FROM silver.dim_department
WHERE department_name != TRIM(department_name);

--- ==========================================================================
--- Checking 'silver.dim_date'
--- ==========================================================================
--- Check for NULLs or Duplicates in Primary Key
--- Expectation: No Results
SELECT 
	date_key,
	COUNT(*)
FROM silver.dim_date
GROUP BY date_key
HAVING COUNT(*) > 1 OR date_key IS NULL;

--- Check Date Range (Expectation: 2015-01-01 to 2018-12-31)
SELECT 
	MIN(full_date) AS min_date,
	MAX(full_date) AS max_date,
	COUNT(*) AS total_days
FROM silver.dim_date;

--- ==========================================================================
--- Checking 'silver.fact_sales'
--- ==========================================================================
--- Check for NULLs or Duplicates in Primary Key
--- Expectation: No Results
SELECT 
	sales_id,
	COUNT(*)
FROM silver.fact_sales
GROUP BY sales_id
HAVING COUNT(*) > 1 OR sales_id IS NULL;

--- Check that all sales rows join to a product (Expectation: 0 unmatched)
SELECT 
	COUNT(*) AS unmatched_products
FROM silver.fact_sales
WHERE product_key IS NULL;

--- Check that all sales rows join to a customer (Expectation: 0 unmatched)
SELECT 
	COUNT(*) AS unmatched_customers
FROM silver.fact_sales
WHERE customer_id IS NULL;

--- Check for Invalid Date Orders (shipping before order)
--- Expectation: No Results
SELECT 
	COUNT(*) AS ship_before_order
FROM silver.fact_sales fs
JOIN silver.dim_date od ON fs.order_date_key = od.date_key
JOIN silver.dim_date sd ON fs.shipping_date_key = sd.date_key
WHERE sd.full_date < od.full_date;

--- Check Data Consistency: sales_amount = product_price * quantity
--- Expectation: 0 mismatches
SELECT 
	COUNT(*) AS sales_formula_mismatches
FROM silver.fact_sales
WHERE ABS(sales_amount - (product_price * quantity)) > 0.01;

--- Check Data Consistency: item_total = sales_amount - discount_amount
--- Expectation: 0 mismatches
SELECT 
	COUNT(*) AS item_total_mismatches
FROM silver.fact_sales
WHERE ABS(item_total - (sales_amount - discount_amount)) > 0.01;

--- Check Delivery Status values
SELECT DISTINCT
	delivery_status
FROM silver.fact_sales;

--- Check Order Status values
SELECT DISTINCT
	order_status
FROM silver.fact_sales;

--- ==========================================================================
--- Checking 'silver.fact_access_log'
--- ==========================================================================
--- Check for NULLs or Duplicates in Primary Key
--- Expectation: No Results
SELECT 
	log_id,
	COUNT(*)
FROM silver.fact_access_log
GROUP BY log_id
HAVING COUNT(*) > 1 OR log_id IS NULL;

--- Check that all log rows join to a product (Expectation: 0 unmatched)
SELECT 
	COUNT(*) AS unmatched_log_products
FROM silver.fact_access_log
WHERE product_key IS NULL;

--- Check for Unwanted Spaces in url
--- Expectation: No Results
SELECT 
	log_id
FROM silver.fact_access_log
WHERE url != TRIM(url);

--- Check ip address validity (4 octets, each 0-255)
--- Expectation: No Results
SELECT 
	COUNT(*) AS invalid_ips
FROM silver.fact_access_log
WHERE ip IS NULL
   OR PARSENAME(ip, 4) IS NULL
   OR TRY_CAST(PARSENAME(ip, 4) AS INT) IS NULL
   OR TRY_CAST(PARSENAME(ip, 4) AS INT) > 255
   OR TRY_CAST(PARSENAME(ip, 3) AS INT) > 255
   OR TRY_CAST(PARSENAME(ip, 2) AS INT) > 255
   OR TRY_CAST(PARSENAME(ip, 1) AS INT) > 255;

--- ==========================================================================
--- Cross-table consistency: order/customer/product counts bronze vs silver
--- ==========================================================================
--- Expectation: fact_sales rows = bronze.supply_chain_data rows (180,519)
SELECT
    (SELECT COUNT(*) FROM bronze.supply_chain_data) AS bronze_sales_rows,
    (SELECT COUNT(*) FROM silver.fact_sales)        AS silver_sales_rows;

--- Expectation: fact_access_log rows = bronze.tokenized_access_logs rows (469,977)
SELECT
    (SELECT COUNT(*) FROM bronze.tokenized_access_logs) AS bronze_log_rows,
    (SELECT COUNT(*) FROM silver.fact_access_log)      AS silver_log_rows;