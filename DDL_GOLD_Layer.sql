/*
===============================================================================
DDL Script: Create Gold Views (Star Schema)
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema).

    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- Grain: 1 row per customer
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    c.customer_id     AS customer_key,   -- Natural key used as surrogate
    c.first_name      AS first_name,
    c.last_name       AS last_name,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.customer_segment AS customer_segment,
    c.customer_city   AS city,
    c.customer_state  AS state,
    c.customer_country AS country,
    c.customer_zipcode AS zipcode,
    c.latitude        AS latitude,
    c.longitude       AS longitude
FROM silver.dim_customer c;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- Grain: 1 row per product
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    p.product_key        AS product_key,   -- Surrogate key (shared with facts)
    p.product_card_id    AS product_id,
    p.product_name       AS product_name,
    p.product_price      AS product_price,
    p.category_id        AS category_id,
    p.category_name      AS category_name,
    p.department_id      AS department_id,
    p.department_name    AS department_name,
    p.is_in_catalog      AS is_in_catalog, -- 1 = in sales catalog, 0 = log-only
    p.product_desc       AS product_description
FROM silver.dim_product p;
GO

-- =============================================================================
-- Create Dimension: gold.dim_departments
-- Grain: 1 row per department
-- =============================================================================
IF OBJECT_ID('gold.dim_departments', 'V') IS NOT NULL
    DROP VIEW gold.dim_departments;
GO

CREATE VIEW gold.dim_departments AS
SELECT
    d.department_id    AS department_key,  -- Natural key used as surrogate
    d.department_name  AS department_name
FROM silver.dim_department d;
GO

-- =============================================================================
-- Create Dimension: gold.dim_dates
-- Grain: 1 row per day (calendar)
-- =============================================================================
IF OBJECT_ID('gold.dim_dates', 'V') IS NOT NULL
    DROP VIEW gold.dim_dates;
GO

CREATE VIEW gold.dim_dates AS
SELECT
    d.date_key           AS date_key,      -- YYYYMMDD
    d.full_date          AS date,
    d.year               AS year,
    d.quarter            AS quarter,
    d.month              AS month,
    d.month_name         AS month_name,
    d.week_of_year       AS week_of_year,
    d.day_of_month       AS day_of_month,
    d.day_of_week        AS day_of_week,
    d.day_name           AS day_name,
    d.is_weekend         AS is_weekend
FROM silver.dim_date d;
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- Grain: 1 row per order line item
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    fs.order_id            AS order_number,
    fs.order_item_id       AS line_item_number,
    fs.customer_id         AS customer_key,   -- FK to gold.dim_customers
    fs.product_key         AS product_key,    -- FK to gold.dim_products
    fs.order_date_key      AS order_date_key, -- FK to gold.dim_dates
    fs.shipping_date_key   AS shipping_date_key, -- FK to gold.dim_dates
    fs.days_for_shipping_real     AS days_for_shipping_real,
    fs.days_for_shipping_scheduled AS days_for_shipping_scheduled,
    fs.late_delivery_risk  AS late_delivery_risk,
    fs.delivery_status     AS delivery_status,
    fs.order_status        AS order_status,
    fs.shipping_mode       AS shipping_mode,
    fs.market              AS market,
    fs.order_region        AS order_region,
    fs.order_state         AS order_state,
    fs.order_city          AS order_city,
    fs.order_country       AS order_country,
    fs.order_zipcode       AS order_zipcode,
    fs.benefit_per_order   AS benefit_per_order,
    fs.sales_per_customer  AS sales_per_customer,
    fs.product_price       AS product_price,
    fs.quantity            AS quantity,
    fs.discount_amount     AS discount_amount,
    fs.discount_rate       AS discount_rate,
    fs.sales_amount        AS sales_amount,
    fs.item_total          AS item_total,
    fs.profit_per_order    AS profit_per_order,
    fs.profit_ratio        AS profit_ratio
FROM silver.fact_sales fs;
GO

-- =============================================================================
-- Create Fact Table: gold.fact_access_logs
-- Grain: 1 row per product access-log event
-- =============================================================================
IF OBJECT_ID('gold.fact_access_logs', 'V') IS NOT NULL
    DROP VIEW gold.fact_access_logs;
GO

CREATE VIEW gold.fact_access_logs AS
SELECT
    al.log_id            AS log_id,
    al.product_key       AS product_key,    -- FK to gold.dim_products
    al.event_timestamp   AS event_timestamp,
    al.date_key          AS date_key,       -- FK to gold.dim_dates
    al.hour              AS hour,
    al.ip                AS ip,
    al.url               AS url
FROM silver.fact_access_log al;
GO
